# 部署和测试脚本

本目录包含用于构建、部署和测试 strongSwan GmSSL 的各类脚本。

## 构建脚本

### Windows (PowerShell)
- **build-gmssl.ps1** - Windows环境下构建GmSSL的脚本
- **verify-build.ps1** - 验证构建结果

### Linux (Bash)
- **build-gmssl.sh** - Linux环境下构建GmSSL的脚本
- **build-with-gmsm.sh** - 使用国密算法构建的脚本

## 部署脚本

### 服务器部署
- **deploy-server-gmssl.sh** - 部署支持GmSSL的服务器
- **deploy-server.ps1** - Windows版本的服务器部署脚本
- **deploy-vpn.ps1** - VPN部署脚本
- **setup-vpn-server.sh** - VPN服务器设置脚本
- **cloud-vpn-setup-centos.sh** - CentOS云服务器VPN设置

### 离线安装
- **install-offline.sh** - 离线安装脚本
- **prepare-offline-package.ps1** - 准备离线安装包
- **prepare-offline.ps1** - 准备离线环境

## 测试脚本

### 快速测试
- **quick-test-gmsm.ps1** - Windows快速测试国密算法
- **quick-test-gmsm.sh** - Linux快速测试国密算法
- **quick-vpn-test.ps1** - 快速VPN测试
- **setup-vpn-test.ps1** - VPN测试环境设置

### 客户端
- **connect-cloud.ps1** - 连接到云端VPN
- **start-vpn-client.ps1** - 启动VPN客户端

## 配置和证书生成

- **generate-config.sh** - 生成配置文件
- **generate-sm2-certs.sh** - 生成SM2证书
- **server-install-commands.sh** - 服务器安装命令集

## 使用说明

1. **构建项目**：首先运行构建脚本 (`build-gmssl.ps1` 或 `build-gmssl.sh`)
2. **生成证书**：使用 `generate-sm2-certs.sh` 生成国密证书
3. **部署服务器**：运行相应的部署脚本
4. **测试连接**：使用快速测试脚本验证功能

## 注意事项

- Windows脚本 (*.ps1) 需要在PowerShell中运行
- Linux脚本 (*.sh) 需要执行权限：`chmod +x script.sh`
- 某些脚本可能需要管理员/root权限
