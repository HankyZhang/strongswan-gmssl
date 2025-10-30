# strongSwan-GmSSL - 国密算法集成版本

> 基于 strongSwan 5.9.6，集成国密算法（SM2/SM3/SM4）的 IPsec VPN 实现

[![License](https://img.shields.io/badge/license-GPLv2-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-5.9.6-green.svg)](https://github.com/HankyZhang/strongswan-gmssl)

---

## 📖 项目简介

本项目是 strongSwan 的国密算法增强版本，旨在为 IPsec VPN 提供符合中国密码标准的安全通信能力。

### 主要特性

- ✅ **完整的 strongSwan 5.9.6 源码**
- 🔐 **国密算法集成规划**（SM2/SM3/SM4）
- 📚 **中文技术文档**（VPN 原理、密钥管理、算法详解）
- 🛠️ **一键安装配置脚本**
- 🧪 **完整的测试工具**

---

## 🚀 快速开始

### 使用一键脚本

```bash
# 1. 克隆仓库
git clone https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

# 2. 安装依赖
sudo yum install -y pam-devel openssl-devel make gcc gmp-devel gettext-devel wget systemd-devel

# 3. 编译安装
./configure --prefix=/usr/local/strongswan --sysconfdir=/etc \
    --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 --enable-eap-tls \
    --enable-dhcp --enable-openssl --enable-tools --enable-swanctl --enable-vici \
    --enable-systemd --disable-gmp

make -j $(nproc) && sudo make install

# 4. 生成配置
chmod +x generate-config.sh && sudo ./generate-config.sh

# 5. 测试安装
chmod +x test-strongswan.sh && sudo ./test-strongswan.sh

# 6. 启动服务
sudo systemctl start strongswan && sudo systemctl enable strongswan
```

详细步骤请参考 **[CentOS安装配置指南.md](CentOS安装配置指南.md)**

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
| [国密算法映射和应用场景详解](国密算法映射和应用场景详解.md) | SM2/SM3/SM4 算法映射关系 | 所有人 ⭐⭐⭐ |
| [strongSwan国密算法集成详细方案](strongSwan国密算法集成详细方案.md) | 国密集成技术方案 | 开发者 ⭐⭐⭐⭐ |
| [GmSSL集成实施计划](GmSSL集成实施计划.md) | GmSSL 库集成实施步骤 | 开发者 ⭐⭐⭐⭐⭐ |

---

## 🛠️ 实用脚本

### 1. generate-config.sh - 配置生成脚本

```bash
sudo ./generate-config.sh
```

**功能**：创建配置目录、生成证书、配置防火墙、配置内核参数

### 2. test-strongswan.sh - 安装测试脚本

```bash
sudo ./test-strongswan.sh
```

**测试**：系统环境、依赖、安装、配置、证书、网络、服务、日志、算法、连接

---

## 🔐 国密算法集成

### 支持的国密算法

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
