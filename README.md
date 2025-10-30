# strongSwan-GmSSL - 国密算法集成版本

> 基于 strongSwan 5.9.6，集成 GmSSL 3.1.1 国密算法库的 IPsec VPN 实现

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/strongSwan-5.9.6-green.svg)](https://github.com/HankyZhang/strongswan-gmssl)
[![GmSSL](https://img.shields.io/badge/GmSSL-3.1.1-orange.svg)](https://github.com/guanzhi/GmSSL)
[![Algorithms](https://img.shields.io/badge/国密算法-SM2%2FSM3%2FSM4-red.svg)]()

---

## 🆕 国密版本（推荐）

**新增功能**：集成 GmSSL 3.1.1，支持国密算法 SM2/SM3/SM4

### 快速部署

```powershell
# Windows (PowerShell)
cd C:\Code\strongswan
.\deploy-gmssl.ps1
```

```bash
# Linux/云端 (CentOS 7)
wget https://raw.githubusercontent.com/HankyZhang/strongswan-gmssl/master/cloud-vpn-setup-gmssl.sh
chmod +x cloud-vpn-setup-gmssl.sh
./cloud-vpn-setup-gmssl.sh
```

📖 **详细文档**: [GmSSL部署指南.md](GmSSL部署指南.md)

---

## 📖 项目简介

本项目是 strongSwan 的国密算法增强版本，旨在为 IPsec VPN 提供符合中国密码标准的安全通信能力。

### 主要特性

- ✅ **完整的 strongSwan 5.9.6 源码**
- 🔐 **GmSSL 3.1.1 集成**（SM2/SM3/SM4/SM9/ZUC）
- 🔄 **双模式支持**：国密算法 + 传统算法
- 📚 **中文技术文档**（VPN 原理、密钥管理、算法详解）
- 🛠️ **一键部署脚本**（云端 + 本地 Docker）
- 🧪 **完整的测试工具**
- ✅ **已验证部署**：CentOS 7 ↔ Ubuntu 22.04 (Docker)

### 支持的算法

| 类型 | 国密算法 | 传统算法 |
|------|---------|---------|
| 非对称加密 | SM2 | RSA, ECDSA |
| 哈希算法 | SM3 | SHA2-256, SHA2-512 |
| 对称加密 | SM4-CBC, SM4-GCM | AES-128/256 (CBC/GCM) |
| 密钥交换 | SM2 | MODP-2048, MODP-3072 |

---

## 🚀 快速开始

### 方式一：国密版本（推荐）

**云端部署** (CentOS 7)：
```bash
wget https://raw.githubusercontent.com/HankyZhang/strongswan-gmssl/master/cloud-vpn-setup-gmssl.sh
chmod +x cloud-vpn-setup-gmssl.sh
./cloud-vpn-setup-gmssl.sh
```

**本地部署** (Docker):
```powershell
# Windows PowerShell
cd C:\Code\strongswan
docker-compose -f docker-compose.gmssl.yml up -d
```

**自动化部署** (云端 + 本地):
```powershell
# Windows PowerShell - 完整自动化
.\deploy-gmssl.ps1
```

📖 详细文档：**[GmSSL部署指南.md](GmSSL部署指南.md)**

---

### 方式二：传统版本（已验证）

**使用一键脚本**：

```bash
# 1. 克隆仓库
git clone https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

# 2. 云端部署 (CentOS 7)
chmod +x cloud-vpn-setup-centos.sh
./cloud-vpn-setup-centos.sh

# 3. 本地部署 (Docker)
docker-compose up -d

# 4. 验证连接
docker exec strongswan swanctl --list-sas
```

📖 详细文档：**[CentOS安装配置指南.md](CentOS安装配置指南.md)** | **[Docker部署指南.md](Docker部署指南.md)**

---

## 📚 文档索引

### 基础文档

| 文档名称 | 说明 | 适合人群 |
|---------|------|---------|
| [VPN完整工作原理详解](VPN完整工作原理详解.md) | VPN 从协商到数据传输的完整流程 | 初学者 ⭐⭐⭐ |
| [CentOS安装配置指南](CentOS安装配置指南.md) | CentOS 7.6 安装配置完整步骤 | 运维工程师 ⭐⭐⭐ |

### 进阶文档

| 文档名称 | 说明 | 适合人群 |
|---------|------|---------|
| [IKE密钥vs ESP密钥详解](IKE密钥vs ESP密钥详解.md) | 密钥体系和派生过程详解 | 开发者 ⭐⭐⭐⭐ |
| [算法提案详解](算法提案详解.md) | 加密算法提案协商机制 | 开发者 ⭐⭐⭐⭐ |
| [原始strongSwan加密算法调用流程图](原始strongSwan加密算法调用流程图.md) | 代码级别的算法调用流程 | 开发者 ⭐⭐⭐⭐⭐ |

### 国密相关

| 文档名称 | 说明 | 适合人群 |
|---------|------|---------|
| [GmSSL部署指南](GmSSL部署指南.md) | **国密版本完整部署文档** ⭐⭐⭐ | 所有人 |
| [国密算法映射和应用场景详解](国密算法映射和应用场景详解.md) | SM2/SM3/SM4 算法映射关系 | 所有人 ⭐⭐⭐ |
| [strongSwan国密算法集成详细方案](strongSwan国密算法集成详细方案.md) | 国密集成技术方案 | 开发者 ⭐⭐⭐⭐ |
| [GmSSL集成实施计划](GmSSL集成实施计划.md) | GmSSL 库集成实施步骤 | 开发者 ⭐⭐⭐⭐⭐ |

---

## 🛠️ 实用脚本

### 国密版本脚本

| 脚本名称 | 说明 | 平台 |
|---------|------|------|
| `deploy-gmssl.ps1` | **国密版本一键部署** (云端+本地) | Windows |
| `cloud-vpn-setup-gmssl.sh` | 云端 GmSSL + strongSwan 部署 | CentOS 7 |
| `docker-compose.gmssl.yml` | Docker 编排配置 (国密版) | Docker |

### 传统版本脚本

| 脚本名称 | 说明 | 平台 |
|---------|------|------|
| `cloud-vpn-setup-centos.sh` | 云端传统 strongSwan 部署 | CentOS 7 |
| `test-strongswan.sh` | 安装测试脚本 | Linux |
| `generate-config.sh` | 配置生成脚本 | Linux |

### 通用工具

**test-strongswan.sh** - 安装测试：
```bash
sudo ./test-strongswan.sh
```
测试项：系统环境、依赖、安装、配置、证书、网络、服务、日志、算法、连接

---

## 🔐 国密算法集成

### ⚠️ 开发状态

| 组件 | 状态 | 说明 |
|------|------|------|
| GmSSL 3.1.1 库 | ✅ 已集成 | 提供 SM2/SM3/SM4 底层实现 |
| **gmsm 插件** | 🚧 **需要开发** | strongSwan 源码不包含此插件 |
| 部署脚本 | ✅ 就绪 | cloud-vpn-setup-gmssl.sh, deploy-gmssl.ps1 |
| 配置文件 | ✅ 就绪 | swanctl-gmssl.conf |
| 文档 | ✅ 完整 | GmSSL部署指南.md, 国密插件开发指南.md |

### 支持的国密算法

| 算法 | 类型 | 用途 | GmSSL 库 | gmsm 插件 |
|-----|------|------|----------|-----------|
| **SM2** | 非对称加密 | 密钥交换、数字签名 | ✅ 可用 | 🚧 需开发 |
| **SM3** | 哈希算法 | 完整性验证、PRF | ✅ 可用 | 🚧 需开发 |
| **SM4** | 对称加密 | 数据加密 (CBC/GCM) | ✅ 可用 | 🚧 需开发 |

**重要提示**: 
- ✅ GmSSL 3.1.1 库已通过部署脚本集成
- ⚠️ strongSwan 的 `gmsm` 插件尚不存在，需要自行开发
- 📖 完整开发指南：**[国密插件开发指南.md](国密插件开发指南.md)**
- ⏱️ 预计开发时间：9-12 天

### IKE 提案（密钥交换阶段）

```
# 国密优先方案
proposals = sm4cbc-sm3-sm2,sm4cbc128-sm3-modp2048,aes256-sha256-modp2048

# 说明：
# - sm4cbc-sm3-sm2: SM4加密 + SM3哈希 + SM2密钥交换
# - sm4cbc128-sm3-modp2048: SM4加密 + SM3哈希 + MODP2048密钥交换(兼容)
# - aes256-sha256-modp2048: 传统算法(向后兼容)
```

### ESP 提案（数据传输阶段）

```
# 国密优先方案
esp_proposals = sm4gcm128-sm3-modp2048,aes256gcm128-sha256-modp2048

# 说明：
# - sm4gcm128-sm3-modp2048: SM4-GCM加密 + SM3完整性 + MODP2048 PFS
# - aes256gcm128-sha256-modp2048: AES-GCM加密(向后兼容)
```

### 配置示例

国密配置文件：`config/swanctl/swanctl-gmssl.conf`

```bash
connections {
    site-to-cloud-gm {
        version = 2
        proposals = sm4cbc-sm3-sm2,sm4cbc128-sm3-modp2048,aes256-sha256-modp2048
        
        local {
            auth = psk
            id = local-site
        }
        
        remote {
            auth = psk
            id = cloud-site
        }
        
        children {
            cloud-net-gm {
                esp_proposals = sm4gcm128-sm3-modp2048,aes256gcm128-sha256-modp2048
                local_ts = 10.1.0.0/24
                remote_ts = 10.2.0.0/24
            }
        }
    }
}

secrets {
    ike-psk {
        id = local-site
        secret = "MyStrongPSK2024!@#SecureVPN"
    }
}
```

📖 完整配置说明：**[GmSSL部署指南.md](GmSSL部署指南.md)** 第 3 章

---

## 🏗️ 架构说明

### 国密版本架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        strongSwan-GmSSL                         │
├─────────────────────────────────────────────────────────────────┤
│  IKEv2 协商层 (charon)                                          │
│    └─ 算法提案: sm4cbc-sm3-sm2, sm4cbc-sm3-modp2048            │
├─────────────────────────────────────────────────────────────────┤
│  strongSwan 核心库                                              │
│    ├─ libstrongswan (核心功能)                                 │
│    ├─ libcharon (IKE 守护进程)                                 │
│    └─ gmsm plugin (国密算法接口) ← GmSSL 集成点                │
├─────────────────────────────────────────────────────────────────┤
│  GmSSL 3.1.1 库                                                 │
│    ├─ SM2 (ECC 公钥密码)                                       │
│    ├─ SM3 (密码杂凑算法)                                       │
│    ├─ SM4 (分组密码算法)                                       │
│    └─ SM9/ZUC (可选扩展)                                       │
├─────────────────────────────────────────────────────────────────┤
│  Linux 内核 IPsec 栈 (XFRM)                                    │
│    └─ ESP/AH 封装: SM4-CBC, SM4-GCM                            │
└─────────────────────────────────────────────────────────────────┘
```

### 数据流程

1. **IKE_SA 协商**：使用 SM4-CBC + SM3 + SM2 建立安全关联
2. **CHILD_SA 协商**：协商 ESP 参数（SM4-GCM + SM3）
3. **密钥派生**：使用 SM3 作为 PRF 派生加密密钥
4. **数据传输**：内核使用 SM4-GCM 加密 ESP 数据包

---

## 📊 部署状态

### 已验证环境

| 组件 | 版本 | 平台 | 状态 |
|------|------|------|------|
| strongSwan (传统) | 5.9.6 | CentOS 7 | ✅ 已测试 |
| strongSwan (传统) | 5.9.6 | Ubuntu 22.04 (Docker) | ✅ 已测试 |
| strongSwan (国密) | 5.9.6 + GmSSL 3.1.1 | CentOS 7 | 🚧 脚本就绪 |
| strongSwan (国密) | 5.9.6 + GmSSL 3.1.1 | Ubuntu 22.04 (Docker) | 🚧 镜像就绪 |

### 已验证连接

- ✅ **Site-to-Cloud VPN**: 10.1.0.0/24 (本地) ↔ 10.2.0.0/24 (云端 101.126.148.5)
- ✅ **加密算法**: AES-256-CBC + HMAC-SHA2-256
- ✅ **NAT 穿透**: NAT-T (UDP 4500) 正常工作
- 🚧 **国密算法**: SM4-GCM + SM3（配置就绪，待测试）

| 算法 | 类型 | 用途 | 状态 |
|-----|------|------|------|
| **SM2** | 非对称加密 | 密钥交换、数字签名 | 🚧 开发中 |
| **SM3** | 哈希算法 | 完整性验证、PRF | 🚧 开发中 |
| **SM4** | 对称加密 | 数据加密 | 🚧 开发中 |

---

## 📝 许可证

本项目基于 **GPLv2** 许可证，继承自 strongSwan 官方项目。

---

## 🔗 相关链接

- [strongSwan 官网](https://www.strongswan.org/)
- [strongSwan 文档](https://docs.strongswan.org/)
- [GmSSL GitHub](https://github.com/guanzhi/GmSSL)

---

**最后更新**: 2025-10-30  
**版本**: 5.9.6-gmssl-dev
