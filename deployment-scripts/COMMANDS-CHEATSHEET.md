# GMSM VPN 测试 - 快速命令参考

## 🚀 快速开始（3 步）

```powershell
# 1. 上传客户端设置脚本
scp deployment-scripts\setup-client-linux.sh root@<CLIENT_IP>:/tmp/

# 2. 在客户端服务器上运行
ssh root@<CLIENT_IP> "chmod +x /tmp/setup-client-linux.sh && /tmp/setup-client-linux.sh"

# 3. 自动化测试
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Deploy -Test
```

---

## 📦 镜像传输（如果客户端没有镜像）

```powershell
# Windows 端
docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar
scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/

# 客户端端
ssh root@<CLIENT_IP> "docker load -i /tmp/strongswan-gmssl.tar"
```

---

## 🔧 服务器端命令（101.126.148.5）

```bash
# 查看容器状态
docker ps | grep strongswan-gmsm

# 查看日志
docker logs -f strongswan-gmsm

# 加载配置
docker exec strongswan-gmsm swanctl --load-all

# 查看连接定义
docker exec strongswan-gmsm swanctl --list-conns

# 查看活动连接
docker exec strongswan-gmsm swanctl --list-sas

# 查看支持的算法
docker exec strongswan-gmsm swanctl --list-algs | grep -i "sm\|gm"

# 查看监听端口
docker exec strongswan-gmsm netstat -uln | grep -E "500|4500"

# 重启容器
docker restart strongswan-gmsm

# 实时查看连接日志
docker exec strongswan-gmsm swanctl --log
```

---

## 🖥️ 客户端命令（Linux 客户端服务器）

```bash
# 查看容器状态
docker ps | grep strongswan-client

# 查看日志
docker logs -f strongswan-client

# 加载配置
docker exec strongswan-client swanctl --load-all

# 发起连接
docker exec strongswan-client swanctl --initiate --child gmsm-net

# 查看连接状态
docker exec strongswan-client swanctl --list-sas

# 终止连接
docker exec strongswan-client swanctl --terminate --ike gmsm-vpn

# 测试 VPN 连通性
docker exec strongswan-client ping -c 4 10.10.10.1

# 查看路由
docker exec strongswan-client ip route

# 查看分配的 IP
docker exec strongswan-client ip addr show tun0

# 快速测试脚本
/root/test-vpn.sh
```

---

## 💻 Windows 端命令

```powershell
# 部署配置到服务器
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Deploy

# 测试连接
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Test

# 监控日志
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Monitor

# 更新服务器配置
scp config\swanctl\gmsm-psk-server.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"

# 更新客户端配置
scp config\swanctl\gmsm-psk-client.conf root@<CLIENT_IP>:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@<CLIENT_IP> "docker exec strongswan-client swanctl --load-all"

# 查看两端状态
ssh root@<CLIENT_IP> "docker exec strongswan-client swanctl --list-sas"
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-sas"
```

---

## 🔍 诊断命令

### 网络连通性测试

```bash
# 基础连通性
ping 101.126.148.5

# TCP 端口（用于测试，实际 VPN 使用 UDP）
nc -v 101.126.148.5 22

# 查看本地 IP
ip addr show
# 或
hostname -I

# 查看路由
ip route

# 测试 DNS
nslookup google.com
```

### 防火墙检查

```bash
# 服务器端
ssh root@101.126.148.5 "iptables -L -n -v | grep -E '500|4500'"
ssh root@101.126.148.5 "iptables -t nat -L -n -v"

# 如果使用 firewalld
ssh root@101.126.148.5 "firewall-cmd --list-all"

# 如果使用 ufw
ssh root@101.126.148.5 "ufw status verbose"
```

### 日志分析

```bash
# 查看最新日志
docker logs --tail 50 strongswan-client

# 查看特定内容
docker logs strongswan-client 2>&1 | grep -i "error\|fail\|established"

# 实时日志
docker logs -f strongswan-client

# 容器内的日志文件
docker exec strongswan-client tail -f /var/log/strongswan/charon.log

# 搜索特定时间的日志
docker logs strongswan-client 2>&1 | grep "2025-11-11"
```

### 算法和插件检查

```bash
# 查看所有支持的算法
docker exec strongswan-client swanctl --list-algs

# 只看国密相关
docker exec strongswan-client swanctl --list-algs | grep -i "sm\|gm"

# 查看加载的插件
docker exec strongswan-client swanctl --stats

# 查看版本信息
docker exec strongswan-client swanctl --version
```

---

## 📝 配置文件编辑

### 标准算法配置（第一阶段测试）

```bash
# 服务器端: config/swanctl/gmsm-psk-server.conf
proposals = aes256-sha256-modp2048
esp_proposals = aes256-sha256

# 客户端: config/swanctl/gmsm-psk-client.conf  
proposals = aes256-sha256-modp2048
esp_proposals = aes256-sha256
remote_addrs = 101.126.148.5
```

### 国密算法配置（第二阶段测试）

```bash
# 服务器端
proposals = sm4-sm3-modp2048
esp_proposals = sm4-sm3

# 客户端
proposals = sm4-sm3-modp2048
esp_proposals = sm4-sm3
remote_addrs = 101.126.148.5
```

---

## 🎯 常见场景

### 场景 1: 首次部署

```powershell
# 1. 准备客户端环境
scp deployment-scripts\setup-client-linux.sh root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "/tmp/setup-client-linux.sh"

# 2. 传输镜像
docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar
scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "docker load -i /tmp/strongswan-gmssl.tar"

# 3. 自动测试
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Deploy -Test
```

### 场景 2: 更新配置后重新测试

```powershell
# 1. 上传新配置
scp config\swanctl\gmsm-psk-server.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf
scp config\swanctl\gmsm-psk-client.conf root@<CLIENT_IP>:/etc/strongswan-docker/swanctl/swanctl.conf

# 2. 重新加载
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"
ssh root@<CLIENT_IP> "docker exec strongswan-client swanctl --load-all"

# 3. 测试
ssh root@<CLIENT_IP> "/root/test-vpn.sh"
```

### 场景 3: 切换到国密算法

```bash
# 1. 修改配置文件（将 aes256-sha256 改为 sm4-sm3）
# 编辑 config/swanctl/gmsm-psk-server.conf
# 编辑 config/swanctl/gmsm-psk-client.conf

# 2. 上传并重载（同场景 2）

# 3. 验证算法
ssh root@<CLIENT_IP> "docker exec strongswan-client swanctl --list-sas" | grep -i sm
```

### 场景 4: 问题排查

```bash
# 1. 同时查看两端日志
ssh root@<CLIENT_IP> "docker logs --tail 30 strongswan-client" &
ssh root@101.126.148.5 "docker logs --tail 30 strongswan-gmsm"

# 2. 检查容器状态
ssh root@<CLIENT_IP> "docker ps; docker exec strongswan-client swanctl --stats"
ssh root@101.126.148.5 "docker ps; docker exec strongswan-gmsm swanctl --stats"

# 3. 网络诊断
ssh root@<CLIENT_IP> "ping -c 3 101.126.148.5"
ssh root@<CLIENT_IP> "traceroute 101.126.148.5"

# 4. 重启容器
ssh root@<CLIENT_IP> "docker restart strongswan-client"
ssh root@101.126.148.5 "docker restart strongswan-gmsm"
```

---

## 📊 成功标志

### 连接建立成功

```
gmsm-vpn: #1, ESTABLISHED, IKEv2, <hash>
  local  'vpn-client@test.com' @ <CLIENT_IP>
  remote 'vpn-server@test.com' @ 101.126.148.5
  established Xs ago, rekeying in XXXXs
```

### 标准算法

```
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  gmsm-net: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
```

### 国密算法

```
  SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
  gmsm-net: #1, reqid 1, INSTALLED, TUNNEL, ESP:SM4/HMAC_SM3_96
```

### 网络连通

```bash
$ docker exec strongswan-client ping -c 4 10.10.10.1
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=X ms
```

---

## ⚠️ 注意事项

1. **Windows Docker Desktop 不能用作客户端**
   - `--network host` 在 Windows 上不起作用
   - 容器只能获得 WSL2 内部 IP
   - 必须使用 Linux 服务器作为客户端

2. **防火墙配置**
   - 服务器端必须开放 UDP 500/4500
   - 客户端也需要允许出站 UDP 流量

3. **时间同步**
   - 确保两端时间同步（NTP）
   - 时间差异可能导致认证失败

4. **配置一致性**
   - PSK 密钥必须完全一致
   - proposals 需要有共同支持的算法

5. **日志级别**
   - 调试时可以增加日志级别
   - 生产环境建议使用默认级别

---

**版本**: 1.0  
**最后更新**: 2025-11-11
