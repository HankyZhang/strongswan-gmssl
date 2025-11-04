# Docker编译测试快速指南

## 🚀 快速开始

### 1. 构建Docker镜像并启动容器

```bash
# Windows PowerShell
docker-compose -f docker-compose-build.yml up -d strongswan-build

# 进入容器
docker exec -it strongswan-gmsm-build bash
```

### 2. 在容器内编译

```bash
# 执行编译脚本
bash docker-build.sh
```

### 3. 运行测试

```bash
# 执行测试脚本
bash docker-test.sh
```

---

## 📋 详细步骤

### 步骤1: 构建Docker环境

```powershell
# 在Windows PowerShell中执行
cd C:\Code\strongswan

# 构建镜像（首次需要下载GmSSL，需要几分钟）
docker-compose -f docker-compose-build.yml build

# 启动编译容器
docker-compose -f docker-compose-build.yml up -d strongswan-build

# 查看容器状态
docker ps
```

### 步骤2: 进入容器

```powershell
# 进入编译容器
docker exec -it strongswan-gmsm-build bash
```

### 步骤3: 编译strongSwan

在容器内执行：

```bash
# 查看当前目录
pwd  # 应该在 /strongswan

# 检查GmSSL
gmssl version

# 运行编译脚本
bash docker-build.sh
```

编译脚本会自动：
1. 检查GmSSL安装
2. 清理之前的构建
3. 生成configure脚本
4. 配置strongSwan（启用GMSM插件）
5. 编译strongSwan和GMSM插件

### 步骤4: 测试插件

```bash
# 运行测试脚本
bash docker-test.sh
```

测试脚本会：
1. 检查GMSM插件是否生成
2. 检查插件符号和依赖
3. 尝试加载插件并列出支持的算法

### 步骤5: 验证结果

查找编译生成的插件：

```bash
# 查找GMSM插件
find /strongswan -name "libstrongswan-gmsm.so"

# 查看插件大小和依赖
ls -lh src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so
ldd src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so
```

---

## 🐛 常见问题

### 问题1: GmSSL未安装

**解决**: 确保Dockerfile正确构建了GmSSL

```bash
# 检查GmSSL
ls -la /usr/local/include/gmssl/
ls -la /usr/local/lib/libgmssl.*
gmssl version
```

### 问题2: 编译错误

**查看详细错误**:

```bash
# 手动运行configure看详细输出
./configure --enable-gmsm 2>&1 | tee configure.log

# 查看config.log
less config.log
```

### 问题3: 插件未生成

**检查Makefile**:

```bash
# 查看GMSM插件的Makefile
cat src/libstrongswan/plugins/gmsm/Makefile

# 手动编译插件
cd src/libstrongswan/plugins/gmsm
make
```

---

## 📊 期望的输出

### 成功的编译输出应该包含:

```
[5/5] 编译strongSwan和GMSM插件...
Making all in gmsm
  CC       gmsm_plugin.lo
  CC       gmsm_sm3_hasher.lo
  CC       gmsm_sm3_signer.lo
  CC       gmsm_sm3_prf.lo
  CC       gmsm_sm4_crypter.lo
  CC       gmsm_sm2_private_key.lo
  CC       gmsm_sm2_public_key.lo
  CC       gmsm_sm2_dh.lo
  CCLD     libstrongswan-gmsm.la
✓ GMSM插件已生成: ./src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so
```

### 成功的测试输出应该包含:

```
检查支持的哈希算法:
  - HASH_SM3
  
检查支持的加密算法:
  - ENCR_SM4_CBC (key_size: 128)
  
检查支持的PRF算法:
  - PRF_HMAC_SM3
```

---

## 🔧 手动编译步骤（如果脚本失败）

```bash
# 1. 生成configure
./autogen.sh

# 2. 配置
./configure --prefix=/usr --sysconfdir=/etc --enable-gmsm

# 3. 编译
make -j$(nproc)

# 4. 查看结果
find . -name "libstrongswan-gmsm.so"
```

---

## 🎯 下一步

编译成功后：

1. **安装插件**:
```bash
make install
ldconfig
```

2. **配置strongSwan**:
```bash
# 编辑配置文件
vim /etc/strongswan.conf

# 添加GMSM插件加载
charon {
    load = gmsm
}
```

3. **运行strongSwan**:
```bash
# 启动服务
ipsec start

# 查看状态
ipsec status

# 查看已加载的插件
ipsec plugin_list
```

---

## 📝 清理

```powershell
# 停止并删除容器
docker-compose -f docker-compose-build.yml down

# 删除镜像（可选）
docker rmi strongswan_strongswan-build
```

---

## 💡 提示

- 首次构建Docker镜像需要10-15分钟（下载依赖和编译GmSSL）
- 编译strongSwan大约需要2-5分钟
- 可以使用 `docker-compose logs` 查看容器日志
- 源代码在容器和主机之间是共享的（通过volume挂载）
