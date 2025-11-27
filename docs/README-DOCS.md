# 国密 VPN 测试文档导航

## 📚 文档概览

本项目为 strongSwan IPsec VPN 添加了国密算法支持，并提供了完整的测试方案。

### 当前状态

- ✅ GMSM 插件开发完成
- ✅ Docker 镜像构建成功
- ✅ 服务器端部署完成 (101.126.148.5)
- ✅ Windows Docker 网络问题已定位
- ⏳ 等待 Linux 客户端服务器进行测试

---

## 🗂️ 文档结构

### 核心文档

| 文档 | 说明 | 适用场景 |
|------|------|----------|
| [Windows-Docker-Issue-SUMMARY.md](Windows-Docker-Issue-SUMMARY.md) | **推荐首读** - 问题总结与解决方案 | 快速了解问题和解决方案 |
| [GMSM-VPN-Testing-Guide.md](GMSM-VPN-Testing-Guide.md) | 完整的测试指南 | 详细的测试步骤和说明 |
| [Windows-Docker-Network-Issue.md](Windows-Docker-Network-Issue.md) | 详细的问题分析 | 深入了解技术细节 |

### 部署脚本文档

| 文档 | 说明 | 位置 |
|------|------|------|
| [TESTING-README.md](../deployment-scripts/TESTING-README.md) | 测试准备说明 | deployment-scripts/ |
| [COMMANDS-CHEATSHEET.md](../deployment-scripts/COMMANDS-CHEATSHEET.md) | 命令速查表 | deployment-scripts/ |

---

## 🚀 快速导航

### 我想要...

#### 了解发生了什么问题
👉 阅读 [Windows-Docker-Issue-SUMMARY.md](Windows-Docker-Issue-SUMMARY.md)

**快速要点**:
- Windows Docker Desktop 的 `--network host` 不起作用
- 容器只能使用 WSL2 内部 IP (192.168.65.3)
- 服务器无法路由回复到该内部 IP
- **解决方案**: 使用 Linux 服务器作为客户端

---

#### 开始测试 VPN
👉 阅读 [TESTING-README.md](../deployment-scripts/TESTING-README.md)

**3 步开始**:
```powershell
# 1. 设置客户端
scp deployment-scripts\setup-client-linux.sh root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "/tmp/setup-client-linux.sh"

# 2. 传输镜像
docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar
scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/

# 3. 运行测试
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Deploy -Test
```

---

#### 查找常用命令
👉 阅读 [COMMANDS-CHEATSHEET.md](../deployment-scripts/COMMANDS-CHEATSHEET.md)

**最常用的命令**:
```bash
# 发起连接
docker exec strongswan-client swanctl --initiate --child gmsm-net

# 查看状态
docker exec strongswan-client swanctl --list-sas

# 测试连通性
docker exec strongswan-client ping 10.10.10.1
```

---

#### 深入了解技术细节
👉 阅读 [Windows-Docker-Network-Issue.md](Windows-Docker-Network-Issue.md)

**包含内容**:
- 完整的证据链分析
- 网络数据包流向
- Docker Desktop 架构说明
- 详细的排查过程

---

#### 了解完整测试流程
👉 阅读 [GMSM-VPN-Testing-Guide.md](GMSM-VPN-Testing-Guide.md)

**包含内容**:
- 三种解决方案对比
- 详细的测试步骤
- 配置文件示例
- 故障排查指南
- 预期结果说明

---

## 📁 文件清单

### 文档文件 (docs/)

```
docs/
├── README-DOCS.md                          # 本文件 - 文档导航
├── Windows-Docker-Issue-SUMMARY.md         # 问题总结（推荐首读）
├── GMSM-VPN-Testing-Guide.md               # 完整测试指南
└── Windows-Docker-Network-Issue.md         # 详细问题分析
```

### 脚本文件 (deployment-scripts/)

```
deployment-scripts/
├── TESTING-README.md                       # 测试准备说明
├── COMMANDS-CHEATSHEET.md                  # 命令速查表
├── test-gmsm-vpn-linux.ps1                 # 自动化测试脚本（PowerShell）
├── setup-client-linux.sh                   # 客户端环境设置脚本（Bash）
└── ... （其他历史脚本）
```

### 配置文件 (config/swanctl/)

```
config/swanctl/
├── gmsm-psk-server.conf                    # 服务器端配置
├── gmsm-psk-client.conf                    # 客户端配置
├── gmsm-server.conf                        # 服务器端（证书模式）
├── gmsm-client.conf                        # 客户端（证书模式）
└── ... （其他配置示例）
```

---

## 🎯 按角色导航

### 我是项目经理 / 决策者

**需要了解**:
1. [问题总结](Windows-Docker-Issue-SUMMARY.md) - 了解问题和解决方案
2. [测试准备](../deployment-scripts/TESTING-README.md) - 了解需要的资源

**关键信息**:
- 需要一台 Linux 服务器作为客户端
- 测试分两阶段：标准算法 → 国密算法
- 预计测试时间：2-4 小时（包括环境准备）

---

### 我是测试工程师

**按顺序阅读**:
1. [测试准备](../deployment-scripts/TESTING-README.md) - 了解测试环境要求
2. [测试指南](GMSM-VPN-Testing-Guide.md) - 详细测试步骤
3. [命令速查](../deployment-scripts/COMMANDS-CHEATSHEET.md) - 常用命令参考

**测试检查清单**:
- [ ] Linux 客户端服务器已准备
- [ ] Docker 已安装
- [ ] 镜像已传输
- [ ] 服务器端运行正常
- [ ] 配置文件已准备
- [ ] 防火墙已配置

---

### 我是运维工程师

**快速开始**:
1. 参考 [命令速查](../deployment-scripts/COMMANDS-CHEATSHEET.md)
2. 使用自动化脚本 `test-gmsm-vpn-linux.ps1`
3. 遇到问题查看 [测试指南](GMSM-VPN-Testing-Guide.md) 的故障排查部分

**关键脚本**:
- `setup-client-linux.sh` - 客户端自动化设置
- `test-gmsm-vpn-linux.ps1` - Windows 端自动化测试
- `/root/test-vpn.sh` - 客户端快速测试（脚本会自动创建）

---

### 我是开发工程师

**技术深入**:
1. [详细问题分析](Windows-Docker-Network-Issue.md) - 完整的技术分析
2. [测试指南](GMSM-VPN-Testing-Guide.md) - 算法配置和调试

**关键技术点**:
- Windows Docker Desktop 的 `--network host` 限制
- IPsec/IKE 协议的 UDP 通信要求
- GMSM 算法的集成方式
- strongSwan 的配置语法

---

## 🔧 常见任务

### 任务 1: 首次部署测试环境

```powershell
# 参考文档
.\deployment-scripts\TESTING-README.md

# 执行步骤
1. 准备 Linux 客户端服务器
2. 运行 setup-client-linux.sh
3. 传输 Docker 镜像
4. 运行 test-gmsm-vpn-linux.ps1 -Deploy
```

### 任务 2: 测试 VPN 连接

```powershell
# 参考文档
.\deployment-scripts\COMMANDS-CHEATSHEET.md

# 执行命令
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <IP> -Test
```

### 任务 3: 切换到国密算法

```powershell
# 参考文档
.\docs\GMSM-VPN-Testing-Guide.md (第二阶段)

# 步骤
1. 修改配置文件（sm4-sm3）
2. 上传配置
3. 重新加载
4. 测试连接
5. 验证算法
```

### 任务 4: 排查连接问题

```bash
# 参考文档
.\docs\GMSM-VPN-Testing-Guide.md (故障排查部分)
.\deployment-scripts\COMMANDS-CHEATSHEET.md (诊断命令)

# 常用诊断命令
docker logs strongswan-client
docker exec strongswan-client swanctl --list-sas
docker exec strongswan-client swanctl --log
```

---

## 📊 测试流程图

```
开始
  ↓
准备 Linux 客户端服务器
  ↓
运行 setup-client-linux.sh
  ↓
传输 Docker 镜像
  ↓
阶段一：标准算法测试
  ├─ proposals = aes256-sha256-modp2048
  ├─ esp_proposals = aes256-sha256
  └─ 验证连接成功 ✓
  ↓
阶段二：国密算法测试
  ├─ proposals = sm4-sm3-modp2048
  ├─ esp_proposals = sm4-sm3
  └─ 验证使用国密算法 ✓
  ↓
完成 - 记录测试结果
```

---

## 🎓 知识点总结

### Docker 网络相关

| 环境 | `--network host` 行为 | 容器 IP |
|------|---------------------|---------|
| Linux | ✅ 使用主机网络栈 | 主机 IP |
| Windows Docker Desktop | ❌ 使用 WSL2 网络 | WSL2 内部 IP |

### IPsec/IKE 要求

| 要求 | 说明 |
|------|------|
| 双向 UDP 通信 | 客户端和服务器都需要能发送和接收 |
| 可路由的 IP | 源 IP 必须能被对端路由回来 |
| 端口开放 | UDP 500 (IKE), 4500 (NAT-T) |

### GMSM 算法

| 类型 | 标准算法 | 国密算法 |
|------|----------|----------|
| 加密 | AES | SM4 |
| 完整性 | SHA-256 | SM3 |
| 签名 | RSA | SM2 |
| 密钥交换 | DH | (待实现) |

---

## 🔗 外部资源

- [strongSwan 官方文档](https://docs.strongswan.org/)
- [国密算法标准](http://www.gmbz.org.cn/)
- [IKEv2 RFC 7296](https://datatracker.ietf.org/doc/html/rfc7296)
- [Docker 网络文档](https://docs.docker.com/network/)

---

## 📞 支持信息

### 遇到问题？

1. **查看日志**
   ```bash
   docker logs strongswan-client
   docker logs strongswan-gmsm
   ```

2. **检查文档**
   - 问题分析：[Windows-Docker-Network-Issue.md](Windows-Docker-Network-Issue.md)
   - 故障排查：[GMSM-VPN-Testing-Guide.md](GMSM-VPN-Testing-Guide.md)
   - 命令参考：[COMMANDS-CHEATSHEET.md](../deployment-scripts/COMMANDS-CHEATSHEET.md)

3. **常见问题**
   - 连接超时 → 检查防火墙和网络连通性
   - 算法不匹配 → 确认配置文件一致性
   - 认证失败 → 检查 PSK 密钥

---

## 📝 更新日志

### 2025-11-11
- ✅ 完成 Windows Docker 网络问题诊断
- ✅ 创建完整的测试文档集
- ✅ 提供自动化测试脚本
- ✅ 准备 Linux 客户端部署方案

### 下一步计划
- ⏳ 等待 Linux 客户端服务器
- ⏳ 执行标准算法测试
- ⏳ 执行国密算法测试
- ⏳ 记录性能测试数据

---

**文档维护**: 及时更新  
**最后更新**: 2025-11-11  
**版本**: 1.0
