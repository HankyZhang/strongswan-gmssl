# 国密 VPN 内网测试 - 完全手把手教程

**测试环境**: 公司内网  
**发起端**: 10.88.152.32 (站点 A)  
**响应端**: 10.88.152.103 (站点 B)  
**日期**: 2025-11-11

---

## 📋 环境信息

### 基础环境
- **系统**: CentOS Linux release 7.9.2009 (Core)
- **内核**: 4.19.12-1.el7.elrepo.x86_64
- **端口**: 500/UDP、4500/UDP
- **堡垒机**: https://sifortress.sitechcloud.com/

### 网络拓扑
```
站点 A (发起端)              站点 B (响应端)
10.88.152.32                10.88.152.103
192.168.1.0/24    ←→       10.0.2.0/24
```

---

## 🎯 测试目标

分两个阶段：

### 阶段 1: 标准算法验证 (先确保基础功能正常)
- 算法: AES-256 + SHA-256
- 目的: 验证网络和配置正确性

### 阶段 2: 国密算法测试 (核心目标)
- 算法: SM4 + SM3
- 目的: 验证国密插件工作正常

---

## 📦 准备工作

### 第 1 步: 准备源码包 (在你的 Windows 电脑上)

#### 1.1 下载 strongSwan 源码
```bash
# 官方版本 (用于对比)
http://download.strongswan.org/strongswan-5.9.6.tar.gz

# 国密版本 (从 GitHub 下载)
https://github.com/HankyZhang/strongswan-gmssl/archive/refs/heads/master.zip
```

#### 1.2 下载 GmSSL 源码
```bash
# GmSSL 3.1.1
https://github.com/guanzhi/GmSSL/archive/refs/tags/v3.1.1.tar.gz
```

或者直接从你的项目中获取（已包含）：
```powershell
# 在 Windows 上打包
cd C:\Code\strongswan
tar -czf strongswan-gmssl-full.tar.gz GmSSL/ src/ config/ deployment-scripts/

# 通过堡垒机上传到服务器
# 方法见下文
```

---

## 🚀 阶段 1: 标准算法测试 (30 分钟)

> 目的: 先用标准算法验证环境配置正确

### 站点 A (10.88.152.32) - 发起端配置

#### 1.1 安装依赖
```bash
sudo yum install pam-devel openssl-devel make gcc gmp-devel gettext-devel wget -y
```

#### 1.2 下载并解压 strongSwan
```bash
cd /data/vpn/
wget http://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxvf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6
```

#### 1.3 编译安装
```bash
./configure \
  --prefix=/data/vpn/strongswan-5.9.6/bin/ \
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
  --enable-openssl \
  --disable-gmp

make -j 4 && sudo make install
```

#### 1.4 配置 ipsec.conf
```bash
sudo vi /data/vpn/strongswan-5.9.6/bin/etc/ipsec.conf
```

内容：
```
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2"
    uniqueids=no

conn %default
    keyexchange=ikev2
    authby=secret
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!
    ikelifetime=60m
    lifetime=20m
    rekeymargin=3m
    keyingtries=3
    mobike=no

conn siteA-to-siteB
    left=%defaultroute
    leftid=@siteA.example.com
    leftsubnet=192.168.1.0/24
    right=10.88.152.103
    rightid=@siteB.example.com
    rightsubnet=10.0.2.0/24
    auto=start
```

#### 1.5 配置 ipsec.secrets
```bash
sudo vi /data/vpn/strongswan-5.9.6/bin/etc/ipsec.secrets
```

内容：
```
@siteA.example.com @siteB.example.com : PSK "GmSM_VPN_Test_2025"
```

#### 1.6 配置防火墙
```bash
# 开放 UDP 500/4500
sudo firewall-cmd --permanent --add-port=500/udp
sudo firewall-cmd --permanent --add-port=4500/udp
sudo firewall-cmd --reload

# 或者直接关闭防火墙（测试环境）
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

#### 1.7 启用 IP 转发
```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
```

---

### 站点 B (10.88.152.103) - 响应端配置

#### 2.1 安装依赖（同站点 A）
```bash
sudo yum install pam-devel openssl-devel make gcc gmp-devel gettext-devel wget -y
```

#### 2.2 下载并编译（同站点 A）
```bash
cd /data/vpn/
wget http://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxvf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6

./configure \
  --prefix=/data/vpn/strongswan-5.9.6/bin/ \
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
  --enable-openssl \
  --disable-gmp

make -j 4 && sudo make install
```

#### 2.3 配置 ipsec.conf
```bash
sudo vi /data/vpn/strongswan-5.9.6/bin/etc/ipsec.conf
```

内容：
```
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2"
    uniqueids=no

conn %default
    keyexchange=ikev2
    authby=secret
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!
    ikelifetime=60m
    lifetime=20m
    rekeymargin=3m
    keyingtries=3
    mobike=no

conn siteB-to-siteA
    left=%defaultroute
    leftid=@siteB.example.com
    leftsubnet=10.0.2.0/24
    right=10.88.152.32
    rightid=@siteA.example.com
    rightsubnet=192.168.1.0/24
    auto=add
```

#### 2.4 配置 ipsec.secrets
```bash
sudo vi /data/vpn/strongswan-5.9.6/bin/etc/ipsec.secrets
```

内容：
```
@siteA.example.com @siteB.example.com : PSK "GmSM_VPN_Test_2025"
```

#### 2.5 配置防火墙和 IP 转发（同站点 A）
```bash
sudo firewall-cmd --permanent --add-port=500/udp
sudo firewall-cmd --permanent --add-port=4500/udp
sudo firewall-cmd --reload

sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
```

---

### 测试标准算法连接

#### 3.1 启动站点 B (响应端)
```bash
cd /data/vpn/strongswan-5.9.6
sudo ./bin/sbin/ipsec start

# 查看状态
sudo ./bin/sbin/ipsec status
```

#### 3.2 启动站点 A (发起端)
```bash
cd /data/vpn/strongswan-5.9.6
sudo ./bin/sbin/ipsec start

# 查看状态
sudo ./bin/sbin/ipsec status
```

#### 3.3 验证连接
```bash
# 站点 A 上查看
sudo ./bin/sbin/ipsec status

# 应该看到类似输出：
# Security Associations (1 up, 0 connecting):
# siteA-to-siteB[1]: ESTABLISHED 5 seconds ago
#   AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048

# 站点 B 上查看
sudo ./bin/sbin/ipsec status
```

#### 3.4 测试网络连通性
```bash
# 在站点 A 上 ping 站点 B 的内网
ping -c 4 10.0.2.1

# 在站点 B 上 ping 站点 A 的内网
ping -c 4 192.168.1.1
```

#### 3.5 查看详细日志
```bash
# 实时查看日志
sudo tail -f /var/log/messages | grep charon

# 或者查看最近的日志
sudo journalctl -u strongswan -f
```

---

## 🔐 阶段 2: 国密算法测试 (1-2 小时)

> 前提: 阶段 1 测试成功后再进行

### 准备国密版本

#### 4.1 上传源码到服务器

**方式 1: 通过堡垒机 SCP**
```bash
# 在你的 Windows 电脑上
# 先打包整个项目
cd C:\Code\strongswan
tar -czf strongswan-gmssl-full.tar.gz .

# 通过堡垒机上传（具体方法取决于你的堡垒机配置）
# 假设堡垒机支持文件传输，上传到 /tmp/strongswan-gmssl-full.tar.gz
```

**方式 2: 使用 U 盘或共享文件夹**
```bash
# 如果有内网文件服务器，可以放到那里下载
```

**方式 3: 在服务器上直接克隆（如果有内网 Git）**
```bash
# 如果你公司有内网 GitLab 等，可以先推送到那里
```

#### 4.2 解压并准备
```bash
# 在站点 A 和站点 B 上都执行
cd /data/vpn/
tar -zxvf /tmp/strongswan-gmssl-full.tar.gz -C strongswan-gmssl
cd strongswan-gmssl
```

---

### 站点 A - 国密版本配置

#### 5.1 编译 GmSSL
```bash
cd /data/vpn/strongswan-gmssl/GmSSL

# 编译 GmSSL
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr/local ..
make -j4
sudo make install

# 验证安装
gmssl version
# 应该输出: GmSSL 3.1.1

# 测试 SM3
echo "test" | gmssl sm3
# 应该输出哈希值
```

#### 5.2 编译 strongSwan with GMSM
```bash
cd /data/vpn/strongswan-gmssl

# 复制 GMSM 插件到 strongSwan 源码
# (假设你的项目已经包含了 src/libstrongswan/plugins/gmsm/)

./autogen.sh  # 如果需要

./configure \
  --prefix=/data/vpn/strongswan-gmssl/bin/ \
  --enable-openssl \
  --enable-gmsm \
  --with-gmssl=/usr/local \
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
  --enable-addrblock \
  --enable-unity \
  --enable-certexpire \
  --enable-radattr \
  --enable-tools \
  --disable-gmp

make -j4
sudo make install
```

#### 5.3 验证 GMSM 插件
```bash
cd /data/vpn/strongswan-gmssl

# 检查插件是否存在
ls -lh bin/lib/ipsec/plugins/libstrongswan-gmsm.so

# 检查依赖
ldd bin/lib/ipsec/plugins/libstrongswan-gmsm.so
# 应该看到 libgmssl.so

# 启动并查看加载的插件
sudo ./bin/sbin/ipsec start
sudo ./bin/sbin/ipsec listall

# 查看支持的算法
sudo ./bin/sbin/ipsec listalgs
# 应该看到 SM3, SM4 相关的算法
```

#### 5.4 配置国密算法

**停止旧版本**
```bash
cd /data/vpn/strongswan-5.9.6
sudo ./bin/sbin/ipsec stop
```

**配置 ipsec.conf**
```bash
sudo vi /data/vpn/strongswan-gmssl/bin/etc/ipsec.conf
```

内容：
```
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2"
    uniqueids=no

conn %default
    keyexchange=ikev2
    authby=secret
    # 国密算法配置
    # 注意：SM4 可能显示为数字 ID (1031/1032)
    ike=sm4-sm3-modp2048,aes256-sha256-modp2048
    esp=sm4-sm3,aes256-sha256
    ikelifetime=60m
    lifetime=20m
    rekeymargin=3m
    keyingtries=3
    mobike=no

conn siteA-to-siteB-gmsm
    left=%defaultroute
    leftid=@siteA.gmsm.com
    leftsubnet=192.168.1.0/24
    right=10.88.152.103
    rightid=@siteB.gmsm.com
    rightsubnet=10.0.2.0/24
    auto=start
```

**配置 ipsec.secrets**
```bash
sudo vi /data/vpn/strongswan-gmssl/bin/etc/ipsec.secrets
```

内容：
```
@siteA.gmsm.com @siteB.gmsm.com : PSK "GmSM_VPN_Test_2025"
```

---

### 站点 B - 国密版本配置

#### 6.1 编译 GmSSL 和 strongSwan (同站点 A)
```bash
# 重复站点 A 的步骤 5.1 和 5.2
```

#### 6.2 配置国密算法

**停止旧版本**
```bash
cd /data/vpn/strongswan-5.9.6
sudo ./bin/sbin/ipsec stop
```

**配置 ipsec.conf**
```bash
sudo vi /data/vpn/strongswan-gmssl/bin/etc/ipsec.conf
```

内容：
```
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2"
    uniqueids=no

conn %default
    keyexchange=ikev2
    authby=secret
    ike=sm4-sm3-modp2048,aes256-sha256-modp2048
    esp=sm4-sm3,aes256-sha256
    ikelifetime=60m
    lifetime=20m
    rekeymargin=3m
    keyingtries=3
    mobike=no

conn siteB-to-siteA-gmsm
    left=%defaultroute
    leftid=@siteB.gmsm.com
    leftsubnet=10.0.2.0/24
    right=10.88.152.32
    rightid=@siteA.gmsm.com
    rightsubnet=192.168.1.0/24
    auto=add
```

**配置 ipsec.secrets**
```bash
sudo vi /data/vpn/strongswan-gmssl/bin/etc/ipsec.secrets
```

内容：
```
@siteA.gmsm.com @siteB.gmsm.com : PSK "GmSM_VPN_Test_2025"
```

---

### 测试国密算法连接

#### 7.1 启动站点 B (响应端)
```bash
cd /data/vpn/strongswan-gmssl
sudo ./bin/sbin/ipsec start

# 查看支持的算法
sudo ./bin/sbin/ipsec listalgs | grep -i sm
```

#### 7.2 启动站点 A (发起端)
```bash
cd /data/vpn/strongswan-gmssl
sudo ./bin/sbin/ipsec start

# 查看状态
sudo ./bin/sbin/ipsec status
```

#### 7.3 验证使用国密算法
```bash
# 站点 A 上查看详细状态
sudo ./bin/sbin/ipsec statusall

# 查找算法信息
# 如果使用国密算法，应该看到：
# - SM4 (或数字 1031/1032)
# - SM3 (或 HMAC_SM3_96)

# 查看日志确认
sudo tail -100 /var/log/messages | grep -i "sm3\|sm4\|gmsm"
```

#### 7.4 抓包验证（可选）
```bash
# 在站点 A 上抓包
sudo tcpdump -i any -nn udp port 500 or udp port 4500 -w /tmp/ipsec-gmsm.pcap

# 停止后下载 pcap 文件用 Wireshark 分析
# 可以看到加密算法的协商过程
```

---

## 📊 预期结果

### 阶段 1 成功标志
```
站点 A:
Security Associations (1 up, 0 connecting):
siteA-to-siteB[1]: ESTABLISHED
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  
站点 B:
Security Associations (1 up, 0 connecting):
siteB-to-siteA[1]: ESTABLISHED
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048

网络测试:
ping 192.168.1.1 ✅
ping 10.0.2.1 ✅
```

### 阶段 2 成功标志
```
站点 A:
Security Associations (1 up, 0 connecting):
siteA-to-siteB-gmsm[1]: ESTABLISHED
  SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
  或
  1031/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048

站点 B:
Security Associations (1 up, 0 connecting):
siteB-to-siteA-gmsm[1]: ESTABLISHED
  SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048

网络测试:
ping 192.168.1.1 ✅ (通过国密隧道)
ping 10.0.2.1 ✅ (通过国密隧道)
```

---

## 🔧 故障排查

### 问题 1: 连接超时
```bash
# 检查防火墙
sudo firewall-cmd --list-all

# 检查 SELinux
sudo setenforce 0  # 临时关闭测试

# 检查路由
ip route
```

### 问题 2: 插件加载失败
```bash
# 查看插件目录
ls -lh /data/vpn/strongswan-gmssl/bin/lib/ipsec/plugins/

# 查看依赖
ldd /data/vpn/strongswan-gmssl/bin/lib/ipsec/plugins/libstrongswan-gmsm.so

# 检查 libgmssl.so 是否在系统路径
sudo ldconfig -p | grep gmssl

# 如果找不到，添加路径
echo "/usr/local/lib" | sudo tee -a /etc/ld.so.conf.d/gmssl.conf
sudo ldconfig
```

### 问题 3: 算法协商失败
```bash
# 查看日志
sudo tail -100 /var/log/messages | grep "proposal\|algorithm"

# 确认双方配置一致
sudo cat /data/vpn/strongswan-gmssl/bin/etc/ipsec.conf | grep -E "ike=|esp="

# 尝试只用国密算法
ike=sm4-sm3-modp2048!
esp=sm4-sm3!
```

### 问题 4: SM4 算法显示为数字
```bash
# 这是正常的，SM4 可能显示为 1031 或 1032
# 只要连接建立，就说明使用了 SM4
```

---

## 📝 测试检查清单

### 阶段 1 检查清单
- [ ] 两台服务器都安装了依赖
- [ ] strongSwan 5.9.6 编译成功
- [ ] ipsec.conf 配置正确
- [ ] ipsec.secrets PSK 一致
- [ ] 防火墙开放 UDP 500/4500
- [ ] IP 转发已启用
- [ ] 双方 ipsec 服务启动
- [ ] 连接状态显示 ESTABLISHED
- [ ] 可以 ping 通对方内网

### 阶段 2 检查清单
- [ ] GmSSL 编译安装成功
- [ ] libgmssl.so 在系统路径
- [ ] GMSM 插件编译成功
- [ ] GMSM 插件被加载
- [ ] listalgs 显示 SM3/SM4
- [ ] ipsec.conf 配置国密算法
- [ ] 双方 ipsec 服务重启
- [ ] 连接状态显示使用 SM4/SM3
- [ ] 日志确认使用国密算法
- [ ] 网络连通正常

---

## 💡 建议和提示

### 如果内网测试困难

**选项 A: 购买两台外网服务器（推荐）**
- 阿里云 ECS: 约 ¥0.5/小时，按量付费
- 腾讯云 CVM: 约 ¥0.5/小时，按量付费
- 选择相同区域，延迟更低
- 测试完成后删除，成本很低

**选项 B: 使用公司测试环境**
- 申请开通外网访问（仅测试端口）
- 或在 DMZ 区部署

**选项 C: 使用虚拟机**
- 在你的电脑上用 VirtualBox/VMware
- 创建两个 CentOS 7 虚拟机
- 使用 NAT 网络互通

### 调试技巧

1. **逐步测试**：先标准算法，再国密算法
2. **详细日志**：charondebug 开到最高
3. **抓包分析**：tcpdump + Wireshark
4. **对比配置**：确保双方一致
5. **查看源码**：遇到问题查看 GMSM 插件代码

### 文档和支持

- 项目 GitHub: https://github.com/HankyZhang/strongswan-gmssl
- strongSwan 官方文档: https://docs.strongswan.org/
- GmSSL 文档: https://github.com/guanzhi/GmSSL

---

## 📞 需要帮助？

如果遇到问题，提供以下信息会帮助诊断：

1. 错误日志 (`/var/log/messages`)
2. ipsec 状态 (`ipsec statusall`)
3. 插件列表 (`ipsec listall`)
4. 算法列表 (`ipsec listalgs | grep sm`)
5. 网络状态 (`ip addr`, `ip route`)

---

**祝测试顺利！** 🎉

如果成功验证了国密算法，这将是一个非常有意义的技术成果！
