# strongSwan + GmSSL 部署指南

## 📋 概述

本指南描述如何部署集成了 GmSSL 国密算法库的 strongSwan VPN，支持 SM2/SM3/SM4 等国密算法。

### 🎯 特性

- ✅ **国密算法支持**: SM2（非对称加密）、SM3（哈希）、SM4（对称加密）
- ✅ **向后兼容**: 同时支持传统算法（AES、SHA2、RSA）
- ✅ **双端部署**: 云端（CentOS 7）+ 本地（Docker Ubuntu 22.04）
- ✅ **自动化脚本**: 一键部署和配置
- ✅ **源码编译**: 从 GitHub 仓库直接编译，便于定制

---

## 🏗️ 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    strongSwan + GmSSL                        │
├─────────────────────────────────────────────────────────────┤
│  IKE/IPsec 协议层                                            │
│  ├── IKEv2 协商（支持 SM2 密钥交换）                         │
│  ├── ESP 加密（支持 SM4-GCM/SM4-CBC）                        │
│  └── 认证/完整性（支持 SM3 HMAC）                            │
├─────────────────────────────────────────────────────────────┤
│  加密算法层                                                   │
│  ├── GmSSL 插件                                              │
│  │   ├── SM2（非对称加密/签名）                              │
│  │   ├── SM3（哈希/HMAC）                                    │
│  │   └── SM4（对称加密：CBC/GCM/CTR）                        │
│  └── OpenSSL 插件（传统算法）                                 │
│      ├── RSA/ECDSA（非对称）                                 │
│      ├── SHA2（哈希）                                        │
│      └── AES（对称加密）                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📦 依赖组件

### GmSSL 3.1.1
- **用途**: 提供国密算法实现
- **源码**: https://github.com/guanzhi/GmSSL
- **算法**: SM2/SM3/SM4/SM9/ZUC

### strongSwan
- **用途**: IKE/IPsec VPN 实现
- **源码**: https://github.com/HankyZhang/strongswan-gmssl
- **版本**: 5.9.x + GmSSL 插件

---

## 🚀 快速开始

### 方式一：自动部署（推荐）

#### 1. 云端部署（CentOS 7）

```bash
# SSH 连接到云主机
ssh root@101.126.148.5

# 下载并执行配置脚本
wget https://raw.githubusercontent.com/HankyZhang/strongswan-gmssl/master/cloud-vpn-setup-gmssl.sh
chmod +x cloud-vpn-setup-gmssl.sh
./cloud-vpn-setup-gmssl.sh
```

配置脚本将自动完成：
- ✅ 安装系统依赖
- ✅ 编译安装 GmSSL 3.1.1
- ✅ 从 GitHub 克隆 strongSwan 仓库
- ✅ 编译安装 strongSwan（集成 GmSSL）
- ✅ 配置系统参数和防火墙
- ✅ 创建 VPN 配置文件
- ✅ 启动 strongSwan 服务

#### 2. 本地部署（Docker）

```powershell
# 进入项目目录
cd C:\Code\strongswan

# 构建 GmSSL 版本镜像
docker-compose -f docker-compose.gmssl.yml build

# 启动容器
docker-compose -f docker-compose.gmssl.yml up -d

# 查看日志
docker-compose -f docker-compose.gmssl.yml logs -f strongswan-gmssl
```

---

## 🔧 手动部署

### 云端手动部署

#### 1. 安装依赖

```bash
yum install -y gcc make gmp-devel libcap-ng-devel \
    openssl-devel pam-devel systemd-devel \
    libcurl-devel wget tar gettext git \
    iptables net-tools vim autoconf automake libtool
```

#### 2. 编译 GmSSL

```bash
cd /tmp
wget https://github.com/guanzhi/GmSSL/archive/refs/tags/v3.1.1.tar.gz \
    -O gmssl-3.1.1.tar.gz
tar -zxf gmssl-3.1.1.tar.gz
cd GmSSL-3.1.1

mkdir -p build && cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr/local \
      -DCMAKE_BUILD_TYPE=Release \
      -DENABLE_SM2_PRIVATE=ON \
      -DENABLE_SM3=ON \
      -DENABLE_SM4=ON \
      ..
make -j $(nproc)
make install

# 更新动态链接库
echo "/usr/local/lib" > /etc/ld.so.conf.d/gmssl.conf
ldconfig
```

#### 3. 编译 strongSwan

```bash
cd /tmp
git clone --depth 1 https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

./autogen.sh  # 如果存在

./configure --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-eap-identity \
    --enable-eap-md5 \
    --enable-eap-mschapv2 \
    --enable-eap-tls \
    --enable-dhcp \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --enable-kernel-netlink \
    --enable-gmsm \
    --with-gmssl=/usr/local \
    --disable-gmp \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

make -j $(nproc)
make install
```

#### 4. 配置系统

```bash
# 环境变量
cat > /etc/profile.d/strongswan.sh <<'EOF'
export PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:$PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
EOF
source /etc/profile.d/strongswan.sh

# IP 转发
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sysctl -p

# 创建配置目录
mkdir -p /etc/swanctl/{x509,x509ca,x509sm2,private,rsa,sm2,conf.d}
chmod 700 /etc/swanctl/private
chmod 700 /etc/swanctl/sm2
```

#### 5. 配置防火墙

```bash
# 停止 firewalld
systemctl stop firewalld
systemctl disable firewalld

# 配置 iptables
iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -j MASQUERADE
iptables -I INPUT -p udp --dport 500 -j ACCEPT
iptables -I INPUT -p udp --dport 4500 -j ACCEPT
service iptables save
```

---

## ⚙️ 配置文件

### 云端配置 (/etc/swanctl/swanctl.conf)

```conf
connections {
    cloud-to-site-gm {
        version = 2
        local_addrs = 101.126.148.5
        remote_addrs = 4.149.0.195
        
        local {
            auth = psk
            id = cloud-server-gm
        }
        
        remote {
            auth = psk
            id = site-vpn-gm
        }
        
        children {
            cloud-net-gm {
                local_ts = 10.2.0.0/24
                remote_ts = 10.1.0.0/24
                # 国密算法：SM4-GCM + SM3
                esp_proposals = sm4gcm128-sm3-modp2048
                start_action = start
                dpd_action = restart
            }
        }
        
        # IKE 提案：优先国密
        proposals = sm4cbc-sm3-sm2,aes256-sha256-modp2048
    }
}

secrets {
    ike-cloud-gm {
        id-cloud = cloud-server-gm
        id-site = site-vpn-gm
        secret = "MyStrongPSK2024!@#SecureVPN"
    }
}
```

### 本地配置 (config/swanctl/swanctl-gmssl.conf)

参考项目中的 `config/swanctl/swanctl-gmssl.conf` 文件。

---

## 🔬 测试和验证

### 1. 验证 GmSSL 安装

```bash
# 云端
gmssl version

# 本地（Docker）
docker exec strongswan-gmssl gmssl version
```

期望输出：
```
GmSSL 3.1.1
```

### 2. 验证 strongSwan 插件

```bash
# 云端
/usr/local/strongswan/sbin/charon --version

# 本地
docker exec strongswan-gmssl charon --version
```

检查输出中是否包含 `gmsm` 插件。

### 3. 启动和加载配置

```bash
# 云端
/usr/local/strongswan/libexec/ipsec/charon &
sleep 3
/usr/local/strongswan/sbin/swanctl --load-all

# 本地
docker exec strongswan-gmssl swanctl --load-all
```

### 4. 查看连接配置

```bash
# 云端
/usr/local/strongswan/sbin/swanctl --list-conns

# 本地
docker exec strongswan-gmssl swanctl --list-conns
```

期望看到使用国密算法的连接配置。

### 5. 发起连接

```bash
# 从本地发起
docker exec strongswan-gmssl swanctl --initiate --child cloud-net-gm
```

### 6. 查看连接状态

```bash
# 本地
docker exec strongswan-gmssl swanctl --list-sas

# 云端
/usr/local/strongswan/sbin/swanctl --list-sas
```

期望输出显示 `ESTABLISHED` 状态，并且使用 SM4/SM3 算法。

---

## 📊 算法映射

### ESP（数据加密）算法提案

| 提案格式 | 加密算法 | 完整性算法 | DH组 | 说明 |
|---------|---------|-----------|------|------|
| `sm4gcm128-sm3-modp2048` | SM4-GCM-128 | SM3 | MODP-2048 | 国密认证加密 |
| `sm4cbc-sm3-modp2048` | SM4-CBC | HMAC-SM3 | MODP-2048 | 国密传统模式 |
| `aes256-sha256-modp2048` | AES-256-CBC | HMAC-SHA2-256 | MODP-2048 | 传统算法 |

### IKE（密钥交换）算法提案

| 提案格式 | 加密 | PRF | 完整性 | DH组 | 说明 |
|---------|-----|-----|--------|------|------|
| `sm4cbc-sm3-sm2` | SM4-CBC | PRF-SM3 | HMAC-SM3 | SM2 | 纯国密 |
| `sm4cbc128-sm3-modp2048` | SM4-CBC-128 | PRF-SM3 | HMAC-SM3 | MODP-2048 | 混合模式 |
| `aes256-sha256-modp2048` | AES-256-CBC | PRF-HMAC-SHA2-256 | HMAC-SHA2-256 | MODP-2048 | 传统算法 |

---

## 🛠️ 常用命令

### 本地 Docker

```powershell
# 构建镜像
docker-compose -f docker-compose.gmssl.yml build

# 启动容器
docker-compose -f docker-compose.gmssl.yml up -d

# 查看日志
docker-compose -f docker-compose.gmssl.yml logs -f

# 进入容器
docker exec -it strongswan-gmssl bash

# 查看连接状态
docker exec strongswan-gmssl swanctl --list-sas

# 发起连接
docker exec strongswan-gmssl swanctl --initiate --child cloud-net-gm

# 重新加载配置
docker exec strongswan-gmssl swanctl --load-all

# 停止容器
docker-compose -f docker-compose.gmssl.yml down
```

### 云端服务器

```bash
# 查看进程
ps aux | grep charon

# 启动服务
/usr/local/strongswan/libexec/ipsec/charon &

# 加载配置
/usr/local/strongswan/sbin/swanctl --load-all

# 查看连接
/usr/local/strongswan/sbin/swanctl --list-conns

# 查看状态
/usr/local/strongswan/sbin/swanctl --list-sas

# 查看日志
tail -f /var/log/messages | grep charon

# 验证 GmSSL
gmssl version
gmssl sm4 -help
```

---

## 🔍 故障排查

### 问题1：插件未加载

**症状**: `charon --version` 输出中没有 `gmsm` 插件

**解决**:
```bash
# 检查 GmSSL 库
ldconfig -p | grep gmssl

# 检查编译配置
grep -i gmsm config.log

# 重新编译并指定 PKG_CONFIG_PATH
PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure --enable-gmsm --with-gmssl=/usr/local
```

### 问题2：算法协商失败

**症状**: 连接失败，日志显示 `NO_PROPOSAL_CHOSEN`

**解决**:
1. 检查双方配置中的算法提案是否一致
2. 确认 `gmsm` 插件已加载
3. 使用混合提案：`sm4cbc-sm3-modp2048,aes256-sha256-modp2048`

### 问题3：库依赖错误

**症状**: `error while loading shared libraries: libgmssl.so.3`

**解决**:
```bash
# 更新库缓存
echo "/usr/local/lib" > /etc/ld.so.conf.d/gmssl.conf
ldconfig

# 验证
ldconfig -p | grep gmssl
```

---

## 📚 参考文档

- **GmSSL**: https://github.com/guanzhi/GmSSL
- **strongSwan**: https://www.strongswan.org/
- **国密算法标准**: http://www.gmbz.org.cn/
- **项目文档**:
  - `strongSwan国密算法集成详细方案.md`
  - `国密算法映射和应用场景详解.md`
  - `GmSSL集成实施计划.md`

---

## ⚠️ 注意事项

1. **性能考虑**: 国密算法可能比传统算法略慢，建议在生产环境进行性能测试

2. **兼容性**: 确保通信双方都支持相同的国密算法版本

3. **证书**: 如使用 SM2 证书，需要使用 GmSSL 工具生成

4. **备份**: 部署前备份原有配置

5. **防火墙**: 确保云端安全组开放 UDP 500 和 4500 端口

---

**更新时间**: 2025-10-30  
**版本**: v1.0-gmssl
