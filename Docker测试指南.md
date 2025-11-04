# 使用 Docker 测试国密算法集成

本文档描述如何使用 Docker 容器测试 strongSwan 的国密算法集成。

## 前置条件

- Docker Desktop 已安装并运行
- Docker Compose 已安装

## 快速开始

### 1. 构建 Docker 镜像

首先构建包含 GmSSL 和 strongSwan 国密插件的 Docker 镜像：

```powershell
# Windows PowerShell
docker-compose -f docker-compose.gmssl.yml build
```

```bash
# Linux/Mac
docker-compose -f docker-compose.gmssl.yml build
```

**注意**：首次构建可能需要 15-30 分钟，因为需要：
- 下载并编译 GmSSL 3.1.1
- 克隆并编译 strongSwan（包含国密插件）

### 2. 运行快速测试

构建完成后，运行测试脚本：

#### Windows PowerShell
```powershell
.\quick-test-gmsm.ps1
```

#### Linux/Mac
```bash
chmod +x quick-test-gmsm.sh
./quick-test-gmsm.sh
```

### 3. 手动测试（可选）

如果您想进入容器手动测试：

```powershell
# 启动容器
docker-compose -f docker-compose.gmssl.yml up -d

# 进入容器
docker exec -it strongswan-gmssl bash

# 在容器内测试
gmssl version                    # 查看 GmSSL 版本
gmssl sm2keygen -pass 1234 \    # 生成 SM2 密钥对
    -out /tmp/sm2_key.pem \
    -pubout /tmp/sm2_pub.pem

# 测试 SM3 哈希
echo "Hello GM/T" | gmssl dgst -sm3

# 测试 SM4 加密
echo "Test Data" > /tmp/plain.txt
gmssl sm4 -e -in /tmp/plain.txt -out /tmp/encrypted.bin \
    -key 0123456789abcdef0123456789abcdef
gmssl sm4 -d -in /tmp/encrypted.bin -out /tmp/decrypted.txt \
    -key 0123456789abcdef0123456789abcdef
diff /tmp/plain.txt /tmp/decrypted.txt

# 退出容器
exit
```

## 测试内容

自动化测试脚本将验证以下内容：

### 1. GmSSL 库
- ✓ GmSSL 版本检查
- ✓ SM2 密钥对生成
- ✓ SM3 哈希计算
- ✓ SM4 加密/解密

### 2. strongSwan 国密插件
- ✓ gmsm 插件文件存在性
- ✓ 插件与 GmSSL 的链接关系
- ✓ strongSwan 算法支持列表

### 3. 集成测试
- ✓ SM2 证书生成
- ✓ 使用国密算法的 IKEv2 连接

## Docker 镜像说明

### 镜像详情
- **基础镜像**: Ubuntu 22.04
- **GmSSL 版本**: 3.1.1
- **strongSwan 版本**: 6.0.3dr1 (带国密补丁)
- **支持的国密算法**:
  - SM2: 椭圆曲线公钥密码算法
  - SM3: 密码哈希算法
  - SM4: 分组密码算法

### 镜像大小
约 500 MB（包含所有依赖和编译工具）

## 配置说明

### 容器配置

容器使用以下配置（参见 `docker-compose.gmssl.yml`）：

```yaml
services:
  strongswan-gmssl:
    image: strongswan-gmssl:3.1.1
    privileged: true          # 需要特权模式以操作网络
    network_mode: host        # 使用主机网络模式
    volumes:
      - ./config/swanctl:/etc/swanctl          # VPN 配置
      - ./logs:/var/log/strongswan             # 日志输出
    environment:
      - GMSSL_ENABLED=1       # 启用国密算法
```

### strongSwan 配置

国密插件配置文件位于 `config/strongswan.conf.gmsm`，主要配置：

```
charon {
    plugins {
        gmsm {
            load = yes
        }
    }
}
```

## 故障排查

### 问题 1: Docker 构建失败

**症状**: 构建过程中出现编译错误

**解决方案**:
1. 确保有足够的磁盘空间（至少 5 GB）
2. 确保 Docker Desktop 分配了足够的内存（至少 4 GB）
3. 清理 Docker 缓存后重试：
   ```powershell
   docker system prune -a
   docker-compose -f docker-compose.gmssl.yml build --no-cache
   ```

### 问题 2: 插件未加载

**症状**: swanctl --list-algs 未显示 SM 算法

**解决方案**:
1. 检查 strongswan.conf 配置
2. 查看日志: `docker logs strongswan-gmssl`
3. 手动加载插件并查看错误信息

### 问题 3: 容器无法启动

**症状**: docker-compose up 失败

**解决方案**:
1. 检查端口占用（500, 4500）
2. 确认 Docker Desktop 正在运行
3. 查看详细日志: `docker-compose -f docker-compose.gmssl.yml logs`

## 性能测试

可以使用以下命令进行性能测试：

```bash
# 进入容器
docker exec -it strongswan-gmssl bash

# SM2 签名性能
time for i in {1..100}; do
    gmssl sm2sign -key /tmp/sm2_key.pem -pass 1234 \
        -in /tmp/test.txt -out /tmp/sig.bin
done

# SM3 哈希性能
time for i in {1..1000}; do
    gmssl dgst -sm3 /tmp/test.txt > /dev/null
done

# SM4 加密性能
time for i in {1..100}; do
    gmssl sm4 -e -in /tmp/test.txt -out /tmp/enc.bin \
        -key 0123456789abcdef0123456789abcdef
done
```

## 清理

测试完成后清理资源：

```powershell
# 停止并删除容器
docker-compose -f docker-compose.gmssl.yml down

# 删除镜像（可选）
docker rmi strongswan-gmssl:3.1.1

# 清理所有未使用的 Docker 资源
docker system prune -a
```

## 下一步

- 查看 `gmsm插件快速开始.md` 了解插件开发详情
- 查看 `VPN配置指南.md` 了解如何配置国密 VPN 连接
- 查看 `generate-sm2-certs.sh` 了解如何生成 SM2 证书

## 相关文件

- `Dockerfile.gmssl` - Docker 镜像定义
- `docker-compose.gmssl.yml` - Docker Compose 配置
- `quick-test-gmsm.ps1` - Windows 测试脚本
- `quick-test-gmsm.sh` - Linux/Mac 测试脚本
- `test-gmsm-plugin.sh` - 详细的插件测试脚本

## 技术支持

如有问题，请查看：
- GitHub Issues
- 项目文档目录
- `SM2实现完成报告.md`
