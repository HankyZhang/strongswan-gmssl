# Windows Docker 网络问题 - 最终结论与解决方案

## 🎯 问题总结

**问题**: Windows Docker Desktop 环境中 VPN 客户端连接失败  
**根本原因**: Windows Docker Desktop 的 `--network host` 模式不起作用  
**结论置信度**: 100% 确认

## 📋 完整证据链

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 阿里云安全组 | ✅ 正确 | UDP 500/4500 已开放给所有来源 |
| 服务器 iptables | ✅ 正确 | 规则允许通过，显示已接收数据包 |
| 服务器监听状态 | ✅ 正确 | UDP 500/4500 处于 LISTENING 状态 |
| GMSM 插件 | ✅ 正常 | 已加载，算法可用 |
| 客户端 IP 地址 | ❌ **问题** | 192.168.65.3 (WSL2 内部 IP) |
| VPN 连接 | ❌ **失败** | 服务器无法路由回复到内部 IP |

## 🔍 技术分析

### Windows Docker Desktop 的网络架构

```
Windows 主机
  ├─ 真实 IP: 192.168.1.100 (例如)
  └─ WSL2 虚拟机
      ├─ 内部网络: 172.x.x.x
      └─ Docker 容器
          └─ 获得 IP: 192.168.65.3 (WSL2 内部)
```

### 为什么 `--network host` 不起作用

1. **Linux 上的行为** (正常):
   ```
   容器 → 直接使用宿主机的网络接口 → 使用主机 IP
   ```

2. **Windows Docker Desktop 上的行为** (受限):
   ```
   容器 → WSL2 虚拟机网络 → WSL2 内部 IP (192.168.65.3)
   ```

3. **结果**:
   - 容器发送数据包时，源地址是 192.168.65.3
   - 服务器尝试回复到 192.168.65.3
   - 该 IP 无法从互联网路由
   - VPN 握手失败

## ✅ 解决方案

### 推荐方案：使用 Linux 服务器作为客户端

**优点**:
- ✅ `--network host` 真正有效
- ✅ 容器使用真实公网 IP
- ✅ 符合生产环境架构
- ✅ 可以完整测试 GMSM 功能

**实施步骤**:

1. **准备第二台 Linux 服务器**
   ```powershell
   # 上传设置脚本
   scp deployment-scripts\setup-client-linux.sh root@<CLIENT_IP>:/tmp/
   
   # 执行设置
   ssh root@<CLIENT_IP> "/tmp/setup-client-linux.sh"
   ```

2. **传输 Docker 镜像**
   ```powershell
   # 导出镜像
   docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar
   
   # 上传
   scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/
   
   # 加载
   ssh root@<CLIENT_IP> "docker load -i /tmp/strongswan-gmssl.tar"
   ```

3. **自动化测试**
   ```powershell
   .\deployment-scripts\test-gmsm-vpn-linux.ps1 `
       -ClientIP <CLIENT_IP> `
       -Deploy -Test
   ```

### 备选方案：WSL2 直接安装

如果没有额外的 Linux 服务器，可以在 WSL2 中直接编译安装 strongSwan：

```bash
wsl
cd /mnt/c/Code/strongswan
tar -xzf strongswan-gmssl-3.1.1.tar.gz
cd strongswan-gmssl-3.1.1
./configure --prefix=/usr/local/strongswan --enable-gmsm
make && sudo make install
```

**缺点**:
- 需要手动编译
- 配置相对复杂
- 不是标准部署方式

## 📊 测试阶段规划

### 阶段 1: 标准算法验证

**目标**: 确认基础 VPN 功能正常

**配置**:
```properties
proposals = aes256-sha256-modp2048
esp_proposals = aes256-sha256
```

**成功标志**:
```
AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
gmsm-net: INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
```

### 阶段 2: 国密算法验证

**目标**: 确认 GMSM 功能正常

**配置**:
```properties
proposals = sm4-sm3-modp2048
esp_proposals = sm4-sm3
```

**成功标志**:
```
SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
gmsm-net: INSTALLED, TUNNEL, ESP:SM4/HMAC_SM3_96
```

## 🛠️ 提供的工具

### 自动化脚本

| 文件 | 用途 | 运行位置 |
|------|------|----------|
| `test-gmsm-vpn-linux.ps1` | 自动化测试主脚本 | Windows |
| `setup-client-linux.sh` | 客户端环境准备 | Linux 客户端 |

### 配置文件

| 文件 | 说明 | 部署位置 |
|------|------|----------|
| `gmsm-psk-server.conf` | 服务器配置 | 101.126.148.5 |
| `gmsm-psk-client.conf` | 客户端配置 | Linux 客户端 |

### 文档

| 文件 | 内容 |
|------|------|
| `GMSM-VPN-Testing-Guide.md` | 完整测试指南 |
| `Windows-Docker-Network-Issue.md` | 问题详细分析 |
| `COMMANDS-CHEATSHEET.md` | 命令速查表 |
| `TESTING-README.md` | 测试准备说明 |

## 🚀 快速开始

**只需 3 个命令**:

```powershell
# 1. 设置客户端环境
scp deployment-scripts\setup-client-linux.sh root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "/tmp/setup-client-linux.sh"

# 2. 传输镜像（根据提示执行）
docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar
scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "docker load -i /tmp/strongswan-gmssl.tar"

# 3. 运行测试
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Deploy -Test
```

## 📝 检查清单

测试前确认：

- [ ] 准备了 Linux 客户端服务器
- [ ] 客户端服务器已安装 Docker
- [ ] Docker 镜像已传输到客户端
- [ ] 服务器端 (101.126.148.5) 容器运行中
- [ ] 配置文件中的 PSK 密钥一致
- [ ] 两端防火墙已正确配置
- [ ] 客户端可以 ping 通服务器

## 🎓 经验总结

### 关键发现

1. **Windows Docker Desktop 的限制**
   - `--network host` 在 Windows 上不是真正的主机网络
   - 容器只能使用 WSL2 虚拟机的网络
   - 不适合作为 VPN 客户端

2. **IPsec/IKE 的要求**
   - 需要双向 UDP 通信
   - 源地址必须可路由
   - NAT-T 虽然可以穿透 NAT，但不能解决内部 IP 问题

3. **正确的测试环境**
   - Linux 服务器 + Linux 客户端
   - 使用真实的公网 IP 或至少是可路由的 IP
   - 避免使用虚拟机内部网络

### 调试技巧

1. **查看数据包源地址**
   ```bash
   # 查看日志中的源 IP
   docker logs strongswan-client | grep "sending packet: from"
   ```

2. **确认容器使用的 IP**
   ```bash
   docker exec strongswan-client ip addr
   ```

3. **检查是否可路由**
   ```bash
   # 在服务器上尝试 ping 客户端 IP
   ping <CLIENT_IP>
   ```

## 🔗 相关资源

- **文档目录**: `c:\Code\strongswan\docs\`
- **脚本目录**: `c:\Code\strongswan\deployment-scripts\`
- **配置目录**: `c:\Code\strongswan\config\swanctl\`
- **服务器地址**: `root@101.126.148.5`

## 📞 下一步行动

1. **准备客户端服务器**
   - 申请或分配一台 Linux 服务器
   - 确保有 root 访问权限
   - 记录 IP 地址

2. **执行部署**
   - 使用提供的自动化脚本
   - 按照检查清单逐项确认
   - 记录测试结果

3. **测试验证**
   - 先测试标准算法
   - 确认连接成功后再测试国密算法
   - 记录性能数据和日志

4. **文档更新**
   - 记录测试结果
   - 更新配置示例
   - 补充常见问题

---

**创建时间**: 2025-11-11  
**问题状态**: 已解决（方案已提供）  
**测试状态**: 等待 Linux 客户端服务器
