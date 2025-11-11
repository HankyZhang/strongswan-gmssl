# 国密算法 VPN 测试准备

本目录包含用于测试 strongSwan GMSM（国密算法）VPN 的脚本和文档。

## 📋 问题背景

在 Windows Docker Desktop 环境中测试 VPN 客户端时发现连接失败。经过详细排查，**100% 确认是 Windows Docker Desktop 的网络架构限制导致**。

详细分析请参考：
- [Windows Docker 网络问题诊断](../docs/Windows-Docker-Network-Issue.md)
- [GMSM VPN 测试指南](../docs/GMSM-VPN-Testing-Guide.md)

## 🎯 解决方案

### 推荐方案：使用两台 Linux 服务器测试

**原因**：
- Windows Docker Desktop 的 `--network host` 不起作用
- 容器只能获得 WSL2 内部 IP（如 192.168.65.3）
- 远程服务器无法路由回复包到该内部 IP
- Linux 上的 Docker 可以真正使用主机网络

**架构**：
```
服务器端 (101.126.148.5)          客户端 (另一台 Linux)
  ↓                                  ↓
strongswan-gmsm 容器        strongswan-client 容器
  ↓                                  ↓
真实公网 IP                    真实公网 IP
```

## 🛠️ 快速开始

### 步骤 1: 准备客户端服务器

在 Windows 上执行：

```powershell
# 上传设置脚本到客户端服务器
scp deployment-scripts/setup-client-linux.sh root@<CLIENT_IP>:/tmp/

# SSH 到客户端服务器执行
ssh root@<CLIENT_IP>
chmod +x /tmp/setup-client-linux.sh
/tmp/setup-client-linux.sh
```

这个脚本会：
- ✅ 安装 Docker（如果未安装）
- ✅ 创建配置目录
- ✅ 加载 Docker 镜像（或提示如何上传）
- ✅ 启动 strongSwan 客户端容器
- ✅ 创建快速测试脚本

### 步骤 2: 传输 Docker 镜像（如果客户端服务器没有镜像）

在 Windows 上执行：

```powershell
# 1. 导出镜像
docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar

# 2. 上传到客户端服务器
scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/

# 3. 在客户端服务器上加载
ssh root@<CLIENT_IP> "docker load -i /tmp/strongswan-gmssl.tar"
```

**提示**：镜像较大（约 300-500MB），传输需要时间。

### 步骤 3: 使用自动化测试脚本

在 Windows 上执行：

```powershell
# 完整测试流程（部署 + 测试）
.\deployment-scripts\test-gmsm-vpn-linux.ps1 `
    -ClientIP <CLIENT_IP> `
    -Deploy `
    -Test

# 或分步执行：

# 1. 仅部署配置
.\deployment-scripts\test-gmsm-vpn-linux.ps1 `
    -ClientIP <CLIENT_IP> `
    -Deploy

# 2. 测试连接
.\deployment-scripts\test-gmsm-vpn-linux.ps1 `
    -ClientIP <CLIENT_IP> `
    -Test

# 3. 实时监控日志
.\deployment-scripts\test-gmsm-vpn-linux.ps1 `
    -ClientIP <CLIENT_IP> `
    -Monitor
```

### 步骤 4: 手动测试（可选）

如果想在客户端服务器上手动测试：

```bash
# SSH 到客户端服务器
ssh root@<CLIENT_IP>

# 使用快速测试脚本
/root/test-vpn.sh

# 或手动执行命令
docker exec strongswan-client swanctl --load-all
docker exec strongswan-client swanctl --initiate --child gmsm-net
docker exec strongswan-client swanctl --list-sas
docker exec strongswan-client ping -c 4 10.10.10.1
```

## 📝 测试阶段

### 阶段 1: 标准算法测试（验证基础连接）

**配置**：
```properties
# IKE
proposals = aes256-sha256-modp2048

# ESP
esp_proposals = aes256-sha256
```

**目标**：验证 VPN 基础功能正常工作

**成功标志**：
```
gmsm-vpn: #1, ESTABLISHED, IKEv2
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  gmsm-net: #1, INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
```

### 阶段 2: 国密算法测试（验证 GMSM 功能）

**配置**：
```properties
# IKE
proposals = sm4-sm3-modp2048

# ESP
esp_proposals = sm4-sm3
```

**目标**：验证国密算法正常工作

**成功标志**：
```
gmsm-vpn: #1, ESTABLISHED, IKEv2
  SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
  gmsm-net: #1, INSTALLED, TUNNEL, ESP:SM4/HMAC_SM3_96
```

## 📂 文件说明

### 脚本文件

| 文件 | 说明 | 用途 |
|------|------|------|
| `test-gmsm-vpn-linux.ps1` | 自动化测试脚本 | 在 Windows 上运行，远程操作两台服务器 |
| `setup-client-linux.sh` | 客户端环境准备脚本 | 在客户端 Linux 服务器上运行 |
| `deploy-gmsm-vpn.ps1` | 旧版部署脚本 | 已不推荐使用（Windows Docker 限制） |

### 配置文件

| 文件 | 说明 | 部署位置 |
|------|------|----------|
| `../config/swanctl/gmsm-psk-server.conf` | 服务器端配置 | 101.126.148.5 |
| `../config/swanctl/gmsm-psk-client.conf` | 客户端配置 | 客户端 Linux 服务器 |

### 文档文件

| 文件 | 说明 |
|------|------|
| `../docs/Windows-Docker-Network-Issue.md` | Windows Docker 网络问题详细分析 |
| `../docs/GMSM-VPN-Testing-Guide.md` | 完整的测试指南 |

## 🔧 故障排查

### 问题 1: 连接超时

```bash
# 检查网络连通性
ping <SERVER_IP>

# 检查 UDP 端口（需要在两端同时测试）
nc -u -v <SERVER_IP> 500
nc -u -v <SERVER_IP> 4500

# 查看客户端日志
docker logs strongswan-client | tail -50

# 查看服务器日志
ssh root@101.126.148.5 "docker logs strongswan-gmsm | tail -50"
```

### 问题 2: 算法不匹配

```bash
# 查看双方支持的算法
docker exec strongswan-client swanctl --list-algs
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-algs"

# 确认插件加载状态
docker exec strongswan-client swanctl --stats
```

### 问题 3: 认证失败

```bash
# 检查配置文件中的密钥是否一致
docker exec strongswan-client grep -A 3 "secrets" /etc/swanctl/swanctl.conf
ssh root@101.126.148.5 "docker exec strongswan-gmsm grep -A 3 'secrets' /etc/swanctl/swanctl.conf"

# 查看详细日志
docker logs strongswan-client 2>&1 | grep -i "auth\|psk\|secret"
```

## 📊 预期结果

### 标准算法测试成功
```bash
$ docker exec strongswan-client swanctl --list-sas
gmsm-vpn: #1, ESTABLISHED, IKEv2, <hash>
  local  'vpn-client@test.com' @ <CLIENT_IP>
  remote 'vpn-server@test.com' @ 101.126.148.5
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  established 5s ago, rekeying in 3595s
  gmsm-net: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
    installed 5s ago, rekeying in 3295s, expires in 3895s
    in  568 bytes,  5 packets
    out 428 bytes,  4 packets

$ docker exec strongswan-client ping -c 4 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=10.2 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=9.8 ms
```

### 国密算法测试成功
```bash
$ docker exec strongswan-client swanctl --list-sas
gmsm-vpn: #1, ESTABLISHED, IKEv2, <hash>
  local  'vpn-client@test.com' @ <CLIENT_IP>
  remote 'vpn-server@test.com' @ 101.126.148.5
  SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
  established 3s ago, rekeying in 3597s
  gmsm-net: #1, reqid 1, INSTALLED, TUNNEL, ESP:SM4/HMAC_SM3_96
    installed 3s ago, rekeying in 3297s, expires in 3897s
    in  412 bytes,  3 packets
    out 328 bytes,  3 packets
```

## 🎯 测试检查清单

在开始测试前，确保：

- [ ] 准备了第二台 Linux 服务器作为客户端
- [ ] 客户端服务器已安装 Docker
- [ ] Docker 镜像已上传到客户端服务器
- [ ] 服务器端容器 (101.126.148.5) 正在运行
- [ ] 服务器端安全组/防火墙已配置
- [ ] 客户端可以 ping 通服务器
- [ ] 配置文件中的密钥一致
- [ ] 时区设置一致（避免证书验证问题）

## 📚 相关文档

- [strongSwan 官方文档](https://docs.strongswan.org/)
- [swanctl 配置参考](https://docs.strongswan.org/docs/5.9/swanctl/swanctl.conf.html)
- [IKEv2 协议](https://datatracker.ietf.org/doc/html/rfc7296)
- [国密算法标准](http://www.gmbz.org.cn/)

## 🤝 贡献

如果发现问题或有改进建议，请：
1. 记录详细的错误日志
2. 提供复现步骤
3. 说明环境信息（操作系统、Docker 版本等）

## 📞 支持

遇到问题可以：
1. 查看 `docs/` 目录下的详细文档
2. 检查日志文件 `/var/log/strongswan/charon.log`
3. 使用 `swanctl --log` 实时查看日志

---

**最后更新**: 2025-11-11  
**测试状态**: 准备就绪，等待 Linux 客户端服务器
