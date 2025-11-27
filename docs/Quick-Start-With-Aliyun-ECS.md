# 阿里云 ECS 国密 VPN 快速部署指南

**目标**: 30 分钟内完成国密 VPN 测试环境搭建

**服务器配置**: 阿里云 ECS (2核1G, CentOS 8.2)  
**测试方式**: 服务端 (101.126.148.5) + 客户端 (新购买的服务器)

---

## 📋 购买后第一步

### 1. 获取服务器信息

购买完成后，记录以下信息：

```
公网IP: _______________  (例如: 47.98.123.45)
用户名: root
密码: _______________  (购买时设置的密码)
```

### 2. 首次登录

**在你的 Windows 电脑上**：

```powershell
# 测试连接
ssh root@<你的新服务器IP>

# 例如：
ssh root@47.98.123.45
```

---

## ⚡ 方案选择

### 方案 A: 新服务器作为客户端（推荐，最简单）

- ✅ 服务端: `101.126.148.5` (已部署国密版 Docker)
- ✅ 客户端: 新购买的服务器
- ✅ 测试时间: 20 分钟
- ✅ 成功率: 极高

### 方案 B: 新服务器作为服务端

- 客户端: `101.126.148.5`
- 服务端: 新购买的服务器
- 测试时间: 30 分钟

**推荐方案 A**，因为你的 `101.126.148.5` 已经配置好了。

---

## 🚀 方案 A: 快速部署（推荐）

### 第 1 步: 配置新服务器（客户端）

#### 1.1 登录新服务器

```bash
ssh root@<你的新服务器IP>
```

#### 1.2 增加 swap（内存只有 1GB，需要扩展）

```bash
# 创建 2GB swap
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab

# 验证
free -h
```

#### 1.3 安装 Docker

```bash
# CentOS 8 安装 Docker
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
sudo systemctl enable docker

# 验证
docker --version
```

#### 1.4 配置防火墙

```bash
# 开放 VPN 端口
sudo firewall-cmd --permanent --add-port=500/udp
sudo firewall-cmd --permanent --add-port=4500/udp
sudo firewall-cmd --reload

# 或者直接关闭（测试环境）
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

#### 1.5 启用 IP 转发

```bash
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.accept_redirects=0
sudo sysctl -w net.ipv4.conf.all.send_redirects=0
echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.accept_redirects = 0" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.all.send_redirects = 0" | sudo tee -a /etc/sysctl.conf
```

---

### 第 2 步: 上传 Docker 镜像到新服务器

**在你的 Windows 电脑上**：

#### 2.1 导出 Docker 镜像（如果还没有）

```powershell
cd C:\Code\strongswan

# 导出镜像
docker save strongswan-gmssl:3.1.1 | gzip > strongswan-gmssl-3.1.1.tar.gz

# 查看文件大小
(Get-Item strongswan-gmssl-3.1.1.tar.gz).Length / 1MB
```

#### 2.2 上传到新服务器

```powershell
# 上传镜像（将 <新服务器IP> 替换为你的服务器 IP）
scp strongswan-gmssl-3.1.1.tar.gz root@<新服务器IP>:/tmp/

# 例如：
scp strongswan-gmssl-3.1.1.tar.gz root@47.98.123.45:/tmp/
```

#### 2.3 在新服务器上加载镜像

**切换到新服务器的 SSH 窗口**：

```bash
# 加载镜像
docker load < /tmp/strongswan-gmssl-3.1.1.tar.gz

# 验证
docker images | grep strongswan
```

---

### 第 3 步: 准备客户端配置文件

#### 3.1 创建配置目录

```bash
sudo mkdir -p /etc/strongswan-docker/swanctl
```

#### 3.2 创建客户端配置

```bash
sudo tee /etc/strongswan-docker/swanctl/swanctl.conf > /dev/null <<'EOF'
connections {
    gmsm-client {
        version = 2
        local_addrs = %any
        remote_addrs = 101.126.148.5
        
        local {
            auth = psk
            id = client@gmsm.vpn
        }
        
        remote {
            auth = psk
            id = server@gmsm.vpn
        }
        
        children {
            gmsm-tunnel {
                local_ts = dynamic
                remote_ts = 10.88.0.0/16
                
                esp_proposals = 1031-sm3,aes256-sha256
                
                start_action = start
                close_action = restart
                dpd_action = restart
            }
        }
        
        proposals = 1031-sm3-modp2048,aes256-sha256-modp2048
    }
}

secrets {
    ike-gmsm {
        id-client = client@gmsm.vpn
        id-server = server@gmsm.vpn
        secret = "GmSM_VPN_Test_2025"
    }
}
EOF
```

---

### 第 4 步: 启动客户端容器

```bash
# 启动容器
docker run -d \
  --name strongswan-gmsm-client \
  --restart=always \
  --privileged \
  --network host \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /lib/modules:/lib/modules:ro \
  strongswan-gmssl:3.1.1

# 查看容器状态
docker ps | grep strongswan

# 查看日志
docker logs strongswan-gmsm-client
```

---

### 第 5 步: 验证连接

#### 5.1 检查连接状态

```bash
# 查看连接状态
docker exec strongswan-gmsm-client swanctl --list-sas

# 应该看到类似输出：
# gmsm-client: #1, ESTABLISHED, IKEv2
#   local  'client@gmsm.vpn' @ <你的新服务器IP>
#   remote 'server@gmsm.vpn' @ 101.126.148.5
#   established 3s ago
#   gmsm-tunnel: #1, INSTALLED, TUNNEL
#     1031/HMAC_SM3_96  ← 这表示使用了国密算法！
```

#### 5.2 查看支持的算法

```bash
# 查看支持的加密算法
docker exec strongswan-gmsm-client swanctl --list-algs | grep -i sm

# 应该看到：
# SM3 (HMAC_SM3_96)
# SM4_CBC (1031)
```

#### 5.3 测试网络连通性

```bash
# Ping 服务端容器的内网地址
docker exec strongswan-gmsm-client ping -c 4 10.88.0.1

# 如果 ping 通，说明 VPN 隧道建立成功！
```

---

### 第 6 步: 在 Windows 上监控（可选）

**在你的 Windows 电脑上**：

```powershell
# 实时查看客户端日志
ssh root@<新服务器IP> "docker logs -f strongswan-gmsm-client"

# 实时查看服务端日志
ssh root@101.126.148.5 "docker logs -f strongswan-gmsm"

# 查看两端的连接状态
ssh root@<新服务器IP> "docker exec strongswan-gmsm-client swanctl --list-sas"
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-sas"
```

---

## ✅ 成功标志

### 客户端（新服务器）

```bash
$ docker exec strongswan-gmsm-client swanctl --list-sas

gmsm-client: #1, ESTABLISHED, IKEv2, 12345678_i*
  local  'client@gmsm.vpn' @ 47.98.123.45[4500]
  remote 'server@gmsm.vpn' @ 101.126.148.5[4500]
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  established 10s ago, reauth in 3590s
  
  gmsm-tunnel: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
    installed 10s ago, rekeying in 1190s, expires in 1550s
    in  c1234567,      0 bytes,     0 packets
    out c7654321,      0 bytes,     0 packets
    local  dynamic
    remote 10.88.0.0/16
```

### 服务端（101.126.148.5）

```bash
$ ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-sas"

gmsm-server: #1, ESTABLISHED, IKEv2, 12345678_r
  local  'server@gmsm.vpn' @ 101.126.148.5[4500]
  remote 'client@gmsm.vpn' @ 47.98.123.45[4500]
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  established 10s ago, reauth in 3590s
  
  gmsm-tunnel: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
    installed 10s ago, rekeying in 1190s, expires in 1550s
    in  c7654321,      0 bytes,     0 packets
    out c1234567,      0 bytes,     0 packets
    local  10.88.0.0/16
    remote dynamic
```

### 🎉 看到 `1031` 或 `SM4` 就说明国密算法生效了！

---

## 🔧 故障排查

### 问题 1: 镜像上传太慢

**解决方案**: 使用阿里云 OSS 中转

```powershell
# 方法 1: 分片上传
# 在 Windows 上
$file = "strongswan-gmssl-3.1.1.tar.gz"
$parts = 10
$size = (Get-Item $file).Length
$partSize = [math]::Ceiling($size / $parts)

# 分割文件
for ($i=0; $i -lt $parts; $i++) {
    $skip = $i * $partSize
    cmd /c "copy /b $file part$i.tmp"
}

# 分别上传小文件
for ($i=0; $i -lt $parts; $i++) {
    scp "part$i.tmp" root@<新服务器IP>:/tmp/
}

# 在服务器上合并
ssh root@<新服务器IP> "cat /tmp/part*.tmp > /tmp/strongswan-gmssl-3.1.1.tar.gz"
```

### 问题 2: 连接超时

```bash
# 在新服务器上检查
# 1. 检查防火墙
sudo firewall-cmd --list-all

# 2. 检查安全组（阿里云控制台）
#    确保入站规则允许: UDP 500, 4500

# 3. 检查日志
docker logs strongswan-gmsm-client | grep -i error

# 4. 手动触发连接
docker exec strongswan-gmsm-client swanctl --load-all
docker exec strongswan-gmsm-client swanctl --initiate --child gmsm-tunnel
```

### 问题 3: 内存不足

```bash
# 检查内存使用
free -h

# 如果 swap 不够，增加到 4GB
sudo swapoff /swapfile
sudo dd if=/dev/zero of=/swapfile bs=1M count=4096
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### 问题 4: Docker 启动失败

```bash
# 查看详细错误
docker logs strongswan-gmsm-client

# 检查内核模块
lsmod | grep -E "af_key|xfrm|esp"

# 如果缺少模块
sudo modprobe af_key
sudo modprobe xfrm_user
sudo modprobe esp4
```

---

## 📊 完整测试流程时间表

| 步骤 | 预计时间 | 说明 |
|------|----------|------|
| 购买服务器 | 2 分钟 | 填写配置信息 |
| 等待开通 | 1-3 分钟 | 阿里云自动开通 |
| 基础配置 | 5 分钟 | Swap + Docker + 防火墙 |
| 上传镜像 | 5-10 分钟 | 取决于网络速度 |
| 配置启动 | 5 分钟 | 配置文件 + 启动容器 |
| 测试验证 | 3 分钟 | 查看状态 + Ping 测试 |
| **总计** | **20-30 分钟** | 从购买到成功 |

---

## 🎯 下一步计划

测试成功后，你可以：

1. **抓包分析**：
   ```bash
   # 在客户端抓包
   docker exec strongswan-gmsm-client tcpdump -i any -nn udp port 500 or udp port 4500 -w /tmp/vpn.pcap -c 100
   
   # 下载分析
   scp root@<新服务器IP>:/tmp/vpn.pcap ./
   ```

2. **性能测试**：
   ```bash
   # 使用 iperf3 测试吞吐量
   docker exec strongswan-gmsm iperf3 -s
   docker exec strongswan-gmsm-client iperf3 -c 10.88.0.1
   ```

3. **集成到生产**：
   - 编写自动化部署脚本
   - 配置监控告警
   - 准备证书模式（替代 PSK）

---

## 💰 成本控制

- **测试期间**: 保持运行，约 ¥1.1/天
- **测试完成**: 
  - 选项 1: 删除服务器（停止计费）
  - 选项 2: 停机保留（只收磁盘费，约 ¥0.3/天）
  - 选项 3: 续费长期使用（¥34/月）

---

## 📞 需要帮助？

如果遇到问题，提供以下信息：

1. 服务器 IP: `<你的新服务器IP>`
2. 错误日志: `docker logs strongswan-gmsm-client`
3. 连接状态: `docker exec strongswan-gmsm-client swanctl --list-sas`
4. 系统信息: `uname -a`, `free -h`, `docker --version`

**祝测试顺利！** 🚀

购买后立即开始，20 分钟内看到国密 VPN 运行！
