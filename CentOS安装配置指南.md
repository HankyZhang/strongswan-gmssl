# strongSwan 5.9.6 CentOS 7.6 安装配置指南

> 本文档提供在 CentOS 7.6 环境下安装、配置和启动 strongSwan 5.9.6 的完整步骤。

---

## 目录

1. [基础环境](#基础环境)
2. [安装依赖](#安装依赖)
3. [下载源码](#下载源码)
4. [编译构建](#编译构建)
5. [配置说明](#配置说明)
6. [启动和测试](#启动和测试)
7. [故障排查](#故障排查)
8. [国密版本编译](#国密版本编译)

---

## 基础环境

### 系统要求

```bash
# 系统版本
CentOS Linux release 7.6.1810 (Core)

# 内核版本
3.10.0-1160.62.1.el7.x86_64

# 最小配置
CPU: 2 核心
内存: 2GB
磁盘: 20GB
```

### 检查系统信息

```bash
# 查看系统版本
cat /etc/redhat-release
# 输出: CentOS Linux release 7.6.1810 (Core)

# 查看内核版本
uname -r
# 输出: 3.10.0-1160.62.1.el7.x86_64

# 查看系统架构
uname -m
# 输出: x86_64
```

---

## 安装依赖

### 必需的开发工具和库

```bash
# 安装编译工具链和依赖库
sudo yum install -y \
    pam-devel \
    openssl-devel \
    make \
    gcc \
    gmp-devel \
    gettext-devel \
    wget \
    systemd-devel \
    curl-devel \
    libcap-ng-devel

# 可选：安装额外的工具
sudo yum install -y \
    vim \
    net-tools \
    tcpdump \
    wireshark
```

### 依赖包说明

| 包名 | 用途 | 必需性 |
|-----|------|--------|
| pam-devel | PAM 认证支持 | 可选 |
| openssl-devel | OpenSSL 加密库 | **必需** |
| make | 构建工具 | **必需** |
| gcc | C 编译器 | **必需** |
| gmp-devel | 大数运算库 | 可选（推荐 OpenSSL） |
| gettext-devel | 国际化支持 | 可选 |
| systemd-devel | systemd 集成 | 推荐 |

---

## 下载源码

### 方法 1：下载官方源码包（推荐）

```bash
# 创建工作目录
mkdir -p /usr/local/src
cd /usr/local/src

# 下载 strongSwan 5.9.6
wget https://download.strongswan.org/strongswan-5.9.6.tar.gz

# 验证下载（可选）
wget https://download.strongswan.org/strongswan-5.9.6.tar.gz.sig
# gpg --verify strongswan-5.9.6.tar.gz.sig

# 解压
tar -zxvf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6

# 查看目录结构
ls -la
```

### 方法 2：Git 克隆（不推荐，易构建失败）

```bash
# 克隆官方仓库
git clone https://github.com/strongswan/strongswan.git
cd strongswan
git checkout 5.9.6

# 生成配置脚本（需要 autotools）
./autogen.sh
```

**注意**：使用官方 tar.gz 包更稳定，避免 autotools 版本兼容问题。

---

## 编译构建

### 配置选项详解

```bash
# 进入源码目录
cd /usr/local/src/strongswan-5.9.6

# 配置编译选项
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-eap-identity \
    --enable-eap-md5 \
    --enable-eap-mschapv2 \
    --enable-eap-tls \
    --enable-eap-ttls \
    --enable-eap-peap \
    --enable-eap-tnc \
    --enable-eap-dynamic \
    --enable-eap-radius \
    --enable-xauth-eap \
    --enable-xauth-pam \
    --enable-dhcp \
    --enable-openssl \
    --enable-addrblock \
    --enable-unity \
    --enable-certexpire \
    --enable-radattr \
    --enable-tools \
    --enable-systemd \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp

# 查看配置摘要
# 配置成功后会显示启用的插件和功能
```

### 配置选项说明

#### EAP 认证模块（远程接入 VPN）

| 选项 | 说明 | 适用场景 |
|-----|------|---------|
| `--enable-eap-identity` | EAP 身份认证 | 基础认证 |
| `--enable-eap-md5` | EAP-MD5 认证 | 简单密码认证 |
| `--enable-eap-mschapv2` | EAP-MSCHAPv2 | Windows 客户端 |
| `--enable-eap-tls` | EAP-TLS | 证书认证 |
| `--enable-eap-ttls` | EAP-TTLS | 隧道 TLS 认证 |
| `--enable-eap-peap` | EAP-PEAP | 保护 EAP 认证 |
| `--enable-eap-radius` | RADIUS 服务器集成 | 企业认证 |

#### XAuth 认证（传统 IKEv1）

| 选项 | 说明 |
|-----|------|
| `--enable-xauth-eap` | XAuth EAP 认证 |
| `--enable-xauth-pam` | XAuth PAM 认证 |

#### 核心功能

| 选项 | 说明 | 必需性 |
|-----|------|--------|
| `--enable-openssl` | OpenSSL 加密库 | **强烈推荐** |
| `--disable-gmp` | 禁用 GMP（使用 OpenSSL） | 推荐 |
| `--enable-dhcp` | DHCP 属性支持 | 远程接入推荐 |
| `--enable-tools` | 管理工具（pki） | 推荐 |
| `--enable-swanctl` | 新配置接口 | **推荐** |
| `--enable-vici` | VICI 接口 | swanctl 必需 |
| `--enable-systemd` | systemd 集成 | CentOS 7+ 推荐 |

#### 安装路径

```bash
--prefix=/usr/local/strongswan    # 安装目录
--sysconfdir=/etc                 # 配置文件目录
```

实际路径：
- 可执行文件：`/usr/local/strongswan/sbin/`
- 配置文件：`/etc/strongswan.conf`, `/etc/swanctl/`
- 库文件：`/usr/local/strongswan/lib/`

### 编译和安装

```bash
# 编译（使用 4 个并发任务）
make -j 4

# 安装
sudo make install

# 验证安装
/usr/local/strongswan/sbin/ipsec version
# 输出: Linux strongSwan U5.9.6/K3.10.0-1160.62.1.el7.x86_64
```

### 编译时常见问题

#### 问题 1：OpenSSL 版本过低

```bash
# 错误: OpenSSL version >= 1.0.2 required
# 解决方案：升级 OpenSSL 或使用 EPEL 仓库

sudo yum install epel-release -y
sudo yum update openssl openssl-devel -y
```

#### 问题 2：缺少 systemd 支持

```bash
# 错误: systemd development headers not found
# 解决方案：
sudo yum install systemd-devel -y
```

#### 问题 3：autotools 版本问题（Git 克隆）

```bash
# 错误: autoreconf: command not found
# 解决方案：安装 autotools（不推荐 Git 方式）
sudo yum install autoconf automake libtool -y
```

---

## 配置说明

### 配置文件结构

```
/etc/
├── strongswan.conf           # 全局配置
├── strongswan.d/             # 模块化配置
│   └── charon/
│       ├── logging.conf      # 日志配置
│       └── plugins/          # 插件配置
├── swanctl/                  # swanctl 配置（推荐）
│   ├── swanctl.conf          # 连接配置
│   ├── x509/                 # 证书目录
│   ├── x509ca/               # CA 证书
│   ├── private/              # 私钥
│   └── rsa/                  # RSA 密钥
└── ipsec.d/                  # 传统配置（IKEv1）
    ├── cacerts/
    ├── certs/
    └── private/
```

### 创建配置目录

```bash
# 创建配置目录结构
sudo mkdir -p /etc/swanctl/{x509,x509ca,private,rsa}

# 设置权限
sudo chmod 700 /etc/swanctl/private
sudo chmod 755 /etc/swanctl/{x509,x509ca}
```

### 基础配置示例

#### 1. strongswan.conf（全局配置）

```bash
# 创建或编辑 /etc/strongswan.conf
sudo vim /etc/strongswan.conf
```

```conf
# /etc/strongswan.conf

charon {
    # 日志配置
    filelog {
        /var/log/strongswan.log {
            time_format = %Y-%m-%d %H:%M:%S
            ike_name = yes
            append = no
            default = 1
            ike = 2
            cfg = 2
            knl = 2
        }
        stderr {
            ike = 2
            cfg = 2
        }
    }
    
    # 插件配置
    plugins {
        openssl {
            load = yes
        }
        kernel-netlink {
            load = yes
        }
    }
    
    # 线程数
    threads = 16
    
    # DNS 服务器
    dns1 = 8.8.8.8
    dns2 = 8.8.4.4
}
```

#### 2. swanctl.conf（站点到站点 VPN）

```bash
# 创建或编辑 /etc/swanctl/swanctl.conf
sudo vim /etc/swanctl/swanctl.conf
```

```conf
# /etc/swanctl/swanctl.conf
# 站点到站点 VPN 配置示例

connections {
    site-to-site {
        # 远程网关地址
        remote_addrs = 192.168.2.1
        
        # IKE 版本
        version = 2
        
        # 本地配置
        local {
            auth = pubkey
            certs = gateway-cert.pem
            id = "CN=gateway1.example.com"
        }
        
        # 远程配置
        remote {
            auth = pubkey
            id = "CN=gateway2.example.com"
        }
        
        # 子 SA 配置
        children {
            tunnel {
                # 本地子网
                local_ts = 10.1.0.0/16
                
                # 远程子网
                remote_ts = 10.2.0.0/16
                
                # ESP 提案
                esp_proposals = aes256-sha256-modp2048
                
                # 启动动作
                start_action = trap
                
                # 重密钥时间
                rekey_time = 1h
            }
        }
        
        # IKE 提案
        proposals = aes256-sha256-modp2048
    }
}

# 私钥配置
secrets {
    private {
        file = gateway-key.pem
    }
}
```

#### 3. swanctl.conf（远程接入 VPN）

```conf
# 远程接入 VPN 服务器配置

connections {
    roadwarrior {
        # 任意远程客户端
        remote_addrs = %any
        
        # IP 地址池
        pools = ippool
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = "vpn.example.com"
        }
        
        remote {
            auth = eap-mschapv2
            id = %any
        }
        
        children {
            rw {
                # 分配所有流量
                local_ts = 0.0.0.0/0
                
                esp_proposals = aes256gcm16-sha256
            }
        }
        
        # 发送证书请求
        send_certreq = no
        
        version = 2
    }
}

# IP 地址池
pools {
    ippool {
        addrs = 10.10.10.0/24
        dns = 8.8.8.8, 8.8.4.4
    }
}

# EAP 用户密码
secrets {
    eap-user1 {
        id = user1@example.com
        secret = "SecurePassword123"
    }
    
    eap-user2 {
        id = user2@example.com
        secret = "AnotherPassword456"
    }
}
```

### 生成证书

#### 使用 strongSwan PKI 工具

```bash
# 1. 生成 CA 私钥和证书
/usr/local/strongswan/sbin/pki --gen --type rsa --size 4096 \
    --outform pem > /etc/swanctl/x509ca/ca-key.pem

/usr/local/strongswan/sbin/pki --self --ca --lifetime 3650 \
    --in /etc/swanctl/x509ca/ca-key.pem \
    --type rsa --dn "C=CN, O=Example, CN=CA" \
    --outform pem > /etc/swanctl/x509ca/ca-cert.pem

# 2. 生成网关私钥
/usr/local/strongswan/sbin/pki --gen --type rsa --size 2048 \
    --outform pem > /etc/swanctl/private/gateway-key.pem

# 3. 生成网关证书请求并签名
/usr/local/strongswan/sbin/pki --pub --in /etc/swanctl/private/gateway-key.pem \
    --type rsa | \
/usr/local/strongswan/sbin/pki --issue --lifetime 1825 \
    --cacert /etc/swanctl/x509ca/ca-cert.pem \
    --cakey /etc/swanctl/x509ca/ca-key.pem \
    --dn "C=CN, O=Example, CN=gateway1.example.com" \
    --san gateway1.example.com \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem > /etc/swanctl/x509/gateway-cert.pem

# 4. 设置权限
chmod 600 /etc/swanctl/private/*
chmod 600 /etc/swanctl/x509ca/ca-key.pem
chmod 644 /etc/swanctl/x509ca/ca-cert.pem
chmod 644 /etc/swanctl/x509/*
```

---

## 启动和测试

### 方法 1：直接启动（开发测试）

```bash
# 启动 strongSwan
sudo /usr/local/strongswan/sbin/ipsec start

# 查看状态
sudo /usr/local/strongswan/sbin/ipsec status

# 查看日志
sudo tail -f /var/log/strongswan.log

# 停止
sudo /usr/local/strongswan/sbin/ipsec stop

# 重启
sudo /usr/local/strongswan/sbin/ipsec restart
```

### 方法 2：systemd 服务（推荐）

```bash
# 创建 systemd 服务文件
sudo vim /etc/systemd/system/strongswan.service
```

```ini
[Unit]
Description=strongSwan IPsec IKEv1/IKEv2 daemon using swanctl
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/strongswan/sbin/charon-systemd
ExecStartPost=/usr/local/strongswan/sbin/swanctl --load-all
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
```

```bash
# 重载 systemd
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start strongswan

# 设置开机自启
sudo systemctl enable strongswan

# 查看状态
sudo systemctl status strongswan

# 查看日志
sudo journalctl -u strongswan -f
```

### 加载配置

```bash
# 加载所有配置
sudo /usr/local/strongswan/sbin/swanctl --load-all

# 仅加载连接配置
sudo /usr/local/strongswan/sbin/swanctl --load-conns

# 仅加载证书
sudo /usr/local/strongswan/sbin/swanctl --load-certs

# 仅加载密钥
sudo /usr/local/strongswan/sbin/swanctl --load-keys
```

### 管理连接

```bash
# 查看所有连接
sudo /usr/local/strongswan/sbin/swanctl --list-conns

# 查看安全关联（SA）
sudo /usr/local/strongswan/sbin/swanctl --list-sas

# 发起连接
sudo /usr/local/strongswan/sbin/swanctl --initiate --child tunnel

# 终止连接
sudo /usr/local/strongswan/sbin/swanctl --terminate --ike site-to-site
```

### 防火墙配置

```bash
# 允许 IKE（UDP 500）
sudo firewall-cmd --permanent --add-port=500/udp

# 允许 NAT-T（UDP 4500）
sudo firewall-cmd --permanent --add-port=4500/udp

# 允许 ESP（协议 50）
sudo firewall-cmd --permanent --add-protocol=esp

# 重载防火墙
sudo firewall-cmd --reload

# 或使用 iptables
sudo iptables -A INPUT -p udp --dport 500 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4500 -j ACCEPT
sudo iptables -A INPUT -p esp -j ACCEPT
```

### 内核参数配置

```bash
# 编辑 sysctl 配置
sudo vim /etc/sysctl.conf
```

```conf
# IP 转发（网关必需）
net.ipv4.ip_forward = 1

# 禁用源地址验证
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# IPsec 优化
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
```

```bash
# 应用配置
sudo sysctl -p
```

---

## 故障排查

### 常用调试命令

```bash
# 查看详细日志
sudo /usr/local/strongswan/sbin/ipsec start --nofork

# 查看 XFRM 状态（内核 IPsec）
sudo ip xfrm state
sudo ip xfrm policy

# 抓包分析
sudo tcpdump -i eth0 -n port 500 or port 4500 or proto esp

# 查看证书
sudo /usr/local/strongswan/sbin/swanctl --list-certs

# 查看配置
sudo /usr/local/strongswan/sbin/swanctl --list-conns
```

### 常见问题

#### 问题 1：连接建立失败

```bash
# 检查日志
tail -100 /var/log/strongswan.log | grep -i error

# 常见原因：
# 1. 防火墙阻止
# 2. 提案不匹配
# 3. 证书验证失败
# 4. 时间不同步
```

#### 问题 2：no proposal found

```
# 日志: no proposal found
# 原因：双方提案不匹配
# 解决：检查 esp_proposals 和 proposals 配置
```

#### 问题 3：authentication failed

```
# 日志: authentication failed
# 原因：证书或密钥问题
# 解决：
#   1. 检查证书链
#   2. 验证私钥权限
#   3. 确认 ID 匹配
```

---

## 国密版本编译

### GmSSL 集成配置

```bash
# 假设 GmSSL 已安装在 /usr/local/gmssl

# 配置 strongSwan with GmSSL
./configure \
    --prefix=/usr/local/strongswan-gmssl \
    --sysconfdir=/etc \
    --with-openssl=/usr/local/gmssl \
    --enable-openssl \
    --enable-gmssl \
    --enable-eap-identity \
    --enable-eap-md5 \
    --enable-eap-mschapv2 \
    --enable-eap-tls \
    --enable-dhcp \
    --enable-tools \
    --enable-swanctl \
    --enable-vici \
    --enable-systemd \
    --disable-gmp

# 编译
make -j 4 && sudo make install
```

### 国密提案配置

```conf
# swanctl.conf 国密配置

connections {
    gm-vpn {
        remote_addrs = 192.168.2.1
        
        local {
            auth = pubkey
            certs = sm2-cert.pem
        }
        
        remote {
            auth = pubkey
        }
        
        children {
            gm-tunnel {
                local_ts = 10.1.0.0/16
                remote_ts = 10.2.0.0/16
                
                # 国密 ESP 提案
                esp_proposals = sm4cbc-sm3
            }
        }
        
        # 国密 IKE 提案
        proposals = sm4cbc-sm3-sm2
    }
}
```

---

## 参考资料

### 官方文档

- strongSwan 官网: https://www.strongswan.org/
- 官方文档: https://docs.strongswan.org/
- Wiki: https://wiki.strongswan.org/

### 配置示例

- 配置参考 1: https://www.zhangqiongjie.com/2473.html
- 配置参考 2: https://www.cnblogs.com/shaoyangz/p/10345698.html

### 相关标准

- RFC 7296: IKEv2
- RFC 4303: ESP
- GB/T 32918: SM2 算法
- GB/T 32905: SM3 算法
- GB/T 32907: SM4 算法

---

## 快速启动脚本

```bash
#!/bin/bash
# strongswan-quick-start.sh

set -e

echo "=== strongSwan 5.9.6 快速安装脚本 ==="

# 1. 安装依赖
echo "[1/5] 安装依赖..."
sudo yum install -y pam-devel openssl-devel make gcc gmp-devel \
    gettext-devel wget systemd-devel curl-devel

# 2. 下载源码
echo "[2/5] 下载源码..."
cd /usr/local/src
wget -c https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxvf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6

# 3. 配置
echo "[3/5] 配置编译选项..."
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-eap-identity \
    --enable-eap-md5 \
    --enable-eap-mschapv2 \
    --enable-eap-tls \
    --enable-dhcp \
    --enable-openssl \
    --enable-tools \
    --enable-swanctl \
    --enable-vici \
    --enable-systemd \
    --disable-gmp

# 4. 编译安装
echo "[4/5] 编译和安装..."
make -j $(nproc)
sudo make install

# 5. 创建配置目录
echo "[5/5] 创建配置目录..."
sudo mkdir -p /etc/swanctl/{x509,x509ca,private,rsa}
sudo chmod 700 /etc/swanctl/private

echo "=== 安装完成！ ==="
echo "可执行文件: /usr/local/strongswan/sbin/ipsec"
echo "配置文件: /etc/swanctl/swanctl.conf"
echo ""
echo "下一步："
echo "1. 配置 /etc/swanctl/swanctl.conf"
echo "2. 生成证书"
echo "3. 启动服务: /usr/local/strongswan/sbin/ipsec start"
```

保存后执行：

```bash
chmod +x strongswan-quick-start.sh
sudo ./strongswan-quick-start.sh
```

---

**文档版本**: 1.0  
**最后更新**: 2025-10-30  
**适用版本**: strongSwan 5.9.6  
**系统平台**: CentOS 7.6
