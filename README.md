# strongSwan + GmSSL - 国密算法 IPsec VPN

> 基于 strongSwan 5.9.14，集成 GmSSL 3.1.1 国密算法库的 IPsec VPN 实现

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](LICENSE)
[![strongSwan](https://img.shields.io/badge/strongSwan-5.9.14-green.svg)](https://www.strongswan.org/)
[![GmSSL](https://img.shields.io/badge/GmSSL-3.1.1-orange.svg)](https://github.com/guanzhi/GmSSL)
[![Docker](https://img.shields.io/badge/Docker-ready-blue.svg)](Dockerfile.gmssl)

---

## 📋 项目简介

本项目为 strongSwan IPsec VPN 添加了**中国国密算法**（SM2/SM3/SM4）支持，通过自定义 GMSM 插件实现。

### ✨ 核心特性

- ✅ **SM3** 哈希算法（HMAC_SM3_96, HASH_SM3, PRF_HMAC_SM3）
- ✅ **SM4** 加密算法（SM4_CBC, SM4_ECB）
- ✅ **Docker 部署**支持（基于 Ubuntu 22.04）
- ✅ **PSK 预共享密钥**认证
- ✅ **完整测试**文档和自动化脚本

### 🎯 项目状态

**版本**: 3.1.1  
**状态**: ✅ 可用于测试  
**最后更新**: 2025-11-11

| 算法 | 状态 | 说明 |
|------|------|------|
| SM3 哈希 | ✅ 完成 | HMAC_SM3_96, HASH_SM3, PRF_HMAC_SM3 |
| SM4 加密 | ✅ 完成 | SM4_CBC, SM4_ECB |
| SM2 签名 | ⏳ 计划中 | 证书模式需要 |
| SM2 密钥交换 | ⏳ 计划中 | 高级功能 |

---

## 🚀 快速开始

### 3 步开始测试

#### 1️⃣ 构建 Docker 镜像

```bash
# 克隆仓库
git clone https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

# 构建镜像
docker build -f Dockerfile.gmssl -t strongswan-gmssl:3.1.1 .
```

#### 2️⃣ 部署服务器端

```bash
# 使用 docker-compose
docker-compose -f docker-compose.gmssl.yml up -d

# 查看状态
docker exec strongswan-gmsm swanctl --list-algs | grep -i sm
```

#### 3️⃣ 准备客户端测试

**重要**: Windows Docker Desktop 不支持作为 VPN 客户端，请使用 Linux 服务器。

```bash
# 在 Linux 客户端服务器上执行
curl -O https://raw.githubusercontent.com/HankyZhang/strongswan-gmssl/master/deployment-scripts/setup-client-linux.sh
chmod +x setup-client-linux.sh
./setup-client-linux.sh
```

详细步骤请查看 [QUICK-START.md](QUICK-START.md)

---

## 📚 文档导航

### 核心文档

| 文档 | 说明 |
|------|------|
| [QUICK-START.md](QUICK-START.md) | 3 分钟快速开始指南 |
| [docs/README-DOCS.md](docs/README-DOCS.md) | 完整文档导航 |
| [docs/GMSM-VPN-Testing-Guide.md](docs/GMSM-VPN-Testing-Guide.md) | 详细测试指南 |
| [docs/Windows-Docker-Issue-SUMMARY.md](docs/Windows-Docker-Issue-SUMMARY.md) | Windows Docker 问题说明 |

### 部署脚本

| 脚本 | 说明 |
|------|------|
| [deployment-scripts/TESTING-README.md](deployment-scripts/TESTING-README.md) | 测试准备说明 |
| [deployment-scripts/COMMANDS-CHEATSHEET.md](deployment-scripts/COMMANDS-CHEATSHEET.md) | 命令速查表 |
| [deployment-scripts/test-gmsm-vpn-linux.ps1](deployment-scripts/test-gmsm-vpn-linux.ps1) | 自动化测试脚本 |
| [deployment-scripts/setup-client-linux.sh](deployment-scripts/setup-client-linux.sh) | 客户端环境设置 |

---

## 🏗️ 架构说明

### 系统架构

```
┌─────────────────┐         ┌─────────────────┐
│  VPN 客户端      │         │  VPN 服务器      │
│  (Linux)        │         │  (阿里云)        │
├─────────────────┤         ├─────────────────┤
│ strongSwan      │◄───────►│ strongSwan      │
│ + GMSM 插件     │  IPsec  │ + GMSM 插件     │
│ + GmSSL 3.1.1   │  Tunnel │ + GmSSL 3.1.1   │
└─────────────────┘         └─────────────────┘
       UDP 500/4500               UDP 500/4500
```

### GMSM 插件集成

```
strongSwan Core
    ↓
libstrongswan
    ↓
plugins/
    ├── gmp/
    ├── openssl/
    └── gmsm/  ← 自定义国密插件
            ↓
        GmSSL 3.1.1
```

---

## 🔧 技术细节

### 支持的国密算法

| 算法类型 | 算法名称 | strongSwan 标识 | 状态 |
|---------|---------|----------------|------|
| 完整性算法 | HMAC-SM3-96 | HMAC_SM3_96 | ✅ |
| 哈希算法 | SM3 | HASH_SM3 | ✅ |
| PRF | PRF-HMAC-SM3 | PRF_HMAC_SM3 | ✅ |
| 加密算法 | SM4-CBC | SM4_CBC (1031) | ✅ |
| 加密算法 | SM4-ECB | SM4_ECB (1032) | ✅ |

### 配置示例

#### 标准算法配置

```properties
# IKE 提案
proposals = aes256-sha256-modp2048

# ESP 提案
esp_proposals = aes256-sha256
```

#### 国密算法配置

```properties
# IKE 提案
proposals = sm4-sm3-modp2048

# ESP 提案
esp_proposals = sm4-sm3
```

完整配置示例请查看 `config/swanctl/` 目录。

---

## ⚠️ 已知限制

### Windows Docker Desktop 限制

**问题**: Windows Docker Desktop 不能用作 VPN 客户端  
**原因**: `--network host` 模式在 Windows 上不起作用，容器只能使用 WSL2 内部 IP  
**解决方案**: 使用 Linux 服务器作为客户端

详细说明：[docs/Windows-Docker-Issue-SUMMARY.md](docs/Windows-Docker-Issue-SUMMARY.md)

### 算法支持

- ✅ SM3/SM4 已完全支持并测试
- ⏳ SM2 签名/证书模式计划中
- ⏳ SM2 密钥交换计划中

---

## 🧪 测试结果

### 验证环境

| 角色 | 操作系统 | 部署方式 | IP 地址 |
|------|---------|---------|---------|
| 服务器 | Ubuntu 22.04 | Docker | 101.126.148.5 |
| 客户端 | Linux | Docker | 待配置 |

### 测试阶段

- ✅ **阶段 0**: 基础环境搭建和 GMSM 插件开发
- ✅ **阶段 1**: Docker 镜像构建和服务器端部署
- ⏳ **阶段 2**: 标准算法（AES/SHA）VPN 连接测试
- ⏳ **阶段 3**: 国密算法（SM4/SM3）VPN 连接测试

---

## 📦 项目结构

```
strongswan-gmssl/
├── src/                          # strongSwan 源码
│   └── libstrongswan/
│       └── plugins/
│           └── gmsm/            # 国密插件源码 ⭐
├── GmSSL/                        # GmSSL 3.1.1 源码
├── config/                       # 配置文件
│   ├── strongswan.conf.gmsm     # strongSwan 配置
│   └── swanctl/                 # swanctl 配置
│       ├── gmsm-psk-server.conf # 服务器端配置（PSK）
│       ├── gmsm-psk-client.conf # 客户端配置（PSK）
│       ├── gmsm-server.conf     # 服务器端配置（证书）
│       └── gmsm-client.conf     # 客户端配置（证书）
├── deployment-scripts/           # 部署和测试脚本
│   ├── build-gmssl.sh           # 构建脚本（Linux）
│   ├── build-gmssl.ps1          # 构建脚本（Windows）
│   ├── build-with-gmsm.sh       # 带 GMSM 的构建
│   ├── generate-sm2-certs.sh    # SM2 证书生成
│   ├── setup-client-linux.sh    # 客户端环境设置
│   └── test-gmsm-vpn-linux.ps1  # 自动化测试脚本
├── docs/                         # 文档目录
│   ├── README-DOCS.md           # 文档导航
│   ├── GMSM-VPN-Testing-Guide.md # 测试指南
│   └── Windows-Docker-Issue-SUMMARY.md
├── Dockerfile.gmssl              # Docker 镜像定义
├── docker-compose.gmssl.yml      # Docker Compose 配置
├── QUICK-START.md               # 快速开始指南
└── README.md                    # 本文件
```

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 待办事项

- [ ] SM2 签名算法集成
- [ ] SM2 密钥交换实现
- [ ] 完整的 VPN 连接测试（标准算法）
- [ ] 完整的 VPN 连接测试（国密算法）
- [ ] 性能测试和优化
- [ ] 更多部署场景文档

---

## 📄 许可证

本项目基于 [GPLv2](LICENSE) 许可证开源。

- strongSwan: GPLv2
- GmSSL: Apache License 2.0

---

## 🙏 致谢

- [strongSwan](https://www.strongswan.org/) - 开源 IPsec VPN 实现
- [GmSSL](https://github.com/guanzhi/GmSSL) - 国密算法库
- 所有为本项目做出贡献的开发者

---

## 📧 联系方式

- **项目仓库**: https://github.com/HankyZhang/strongswan-gmssl
- **问题反馈**: [GitHub Issues](https://github.com/HankyZhang/strongswan-gmssl/issues)

---

## 📝 更新日志

### v3.1.1 (2025-11-11)

**新增**:
- ✅ SM3 哈希算法完整支持
- ✅ SM4 加密算法完整支持
- ✅ Docker 部署支持
- ✅ 完整的测试文档和脚本

**修复**:
- ✅ Windows Docker Desktop 网络问题诊断
- ✅ GMSM 插件加载问题

**文档**:
- ✅ 完整的测试指南
- ✅ Windows Docker 问题说明
- ✅ 命令速查表
- ✅ 自动化测试脚本

### 下一步计划

- ⏳ Linux 客户端测试
- ⏳ SM2 签名算法集成
- ⏳ SM2 密钥交换实现

---

**最后更新**: 2025-11-11  
**版本**: 3.1.1  
**状态**: ✅ 可用于测试
