# 国密 VPN 测试 - 问题根本原因与解决方案

## 🎯 问题根本原因

### 核心问题：proposal 关键字未生成到运行时代码

虽然 `proposal_keywords_static.txt` 中定义了国密算法关键字：
```txt
sm4,              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm3,              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0
prfsm3,           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SM3,            0
```

但这些关键字需要通过 **gperf** 工具生成到 `proposal_keywords_static.c` 才能被 strongSwan 的配置解析器使用。

### 编译流程问题

**之前的 Dockerfile**:
```dockerfile
RUN git clone --depth 1 --branch ${STRONGSWAN_BRANCH} ${STRONGSWAN_REPO} strongswan-gmssl
```
- ❌ 从 GitHub 克隆原始代码
- ❌ 不包含本地修改（crypter.c 的 SM4 名称映射）
- ❌ 使用预生成的 proposal_keywords_static.c（不含 SM4）

**修复后的 Dockerfile**:
```dockerfile
COPY . /tmp/strongswan-gmssl
RUN autoreconf -f -i && ./configure && make
```
- ✅ 使用本地修改的代码
- ✅ autoreconf 会调用 gperf 重新生成 proposal_keywords_static.c
- ✅ 包含 SM4/SM3 的所有修改

---

## 📁 关键文件说明

### 1. proposal_keywords_static.txt
**作用**: 定义配置文件中可用的算法关键字

**位置**: `src/libstrongswan/crypto/proposal/proposal_keywords_static.txt`

**内容（已包含 SM4/SM3）**:
```txt
sm4,              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4cbc,           ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4gcm,           ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128
sm3,              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0
sm3_96,           INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0
prfsm3,           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SM3,            0
```

### 2. proposal_keywords_static.c (生成的)
**作用**: gperf 生成的完美哈希查找代码

**生成规则** (`Makefile.am`):
```makefile
proposal_keywords_static.c: proposal_keywords_static.txt proposal_keywords_static.h
	$(GPERF) -N proposal_get_token_static -m 10 -C -G -c -t -D \
		--output-file=$@ $(srcdir)/crypto/proposal/proposal_keywords_static.txt
```

**问题**: Docker 镜像使用的是预生成的版本，不包含 SM4

### 3. crypter.c
**作用**: 算法枚举名称映射

**修改内容** (已完成):
```c
ENUM_NEXT(encryption_algorithm_names, ENCR_SM4_CBC, ENCR_SM4_GCM_ICV16, ENCR_AES_CFB,
	"SM4_CBC",
	"SM4_GCM_16");
ENUM_END(encryption_algorithm_names, ENCR_SM4_GCM_ICV16);
```

**作用**: 让 `swanctl --list-sas` 显示 "SM4_CBC" 而不是 "1031"

### 4. gmsm_plugin.c
**作用**: GMSM 插件主文件

**修改内容** (已完成):
```c
#ifndef VERSION
#define VERSION "6.0.3dr1"
#endif
```

**作用**: 修复插件加载时的版本字段缺失

---

## 🔧 完整的修改列表

### ✅ 已完成的修改

1. **src/libstrongswan/plugins/gmsm/gmsm_plugin.c**
   - 添加 VERSION 宏定义
   - 修复插件加载失败问题

2. **src/libstrongswan/crypto/crypters/crypter.c**
   - 添加 SM4 算法名称到枚举表
   - 让日志显示友好的算法名称

3. **Dockerfile.gmssl**
   - 修改为使用本地代码 (`COPY . /tmp/strongswan-gmssl`)
   - 添加 `autoreconf -f -i` 强制重新生成配置
   - 添加 `dos2unix` 处理 Windows 换行符

4. **scripts/git-version**
   - 转换为 Unix 换行符 (LF)
   - 修复 Docker 构建时的 `/bin/sh^M: bad interpreter` 错误

### 📋 无需修改的文件

- **src/libstrongswan/crypto/proposal/proposal_keywords_static.txt**
  - 原始代码已包含 SM4/SM3 定义
  - 不需要修改

---

## 🚀 当前编译状态

**正在编译**: strongswan-gmssl:3.1.1-local
- 使用本地修改的代码
- 会自动生成包含 SM4 的 proposal_keywords_static.c
- 预计编译时间: 3-5 分钟

**编译完成后的步骤**:

1. 导出镜像
   ```powershell
   docker save strongswan-gmssl:3.1.1-local -o strongswan-local.tar
   ```

2. 上传到服务器 (101.126.148.5)
   ```powershell
   scp strongswan-local.tar root@101.126.148.5:/tmp/
   ```

3. 加载并更新容器
   ```bash
   docker load < /tmp/strongswan-local.tar
   docker stop strongswan-gmsm && docker rm strongswan-gmsm
   docker run -d --name strongswan-gmsm ... strongswan-gmssl:3.1.1-local
   ```

4. 测试国密配置
   ```bash
   docker exec strongswan-gmsm swanctl --load-all
   ```

**预期结果**:
```
loaded connection 'gmsm-server'
successfully loaded 1 connections, 0 unloaded
```

---

## 🔍 验证方法

### 1. 检查算法注册
```bash
docker exec strongswan-gmsm swanctl --list-algs | grep -i sm
```

**预期输出**:
```
  SM4_CBC[gmsm]         # ← 显示友好名称
  SM4_GCM_16[gmsm]
  HMAC_SM3_96[gmsm]
  HASH_SM3[gmsm]
  PRF_HMAC_SM3[gmsm]
  SM2_256[gmsm]
```

### 2. 加载配置
```bash
docker exec strongswan-gmsm swanctl --load-all
```

**成功标志**:
```
loaded connection 'gmsm-server'
successfully loaded 1 connections, 0 unloaded
```

### 3. 查看连接定义
```bash
docker exec strongswan-gmsm swanctl --list-conns
```

**预期输出**:
```
gmsm-server: IKEv2
  proposals: SM4_CBC-128/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048, AES_CBC-256/...
  ...
```

### 4. 建立 VPN 连接
```bash
# 客户端触发连接
docker exec strongswan-gmsm-client swanctl --initiate --child gmsm-tunnel
```

### 5. 查看连接状态
```bash
docker exec strongswan-gmsm-client swanctl --list-sas
```

**成功标志**:
```
gmsm-client: #1, ESTABLISHED, IKEv2
  SM4_CBC-128/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048  ← 使用国密算法！
  
  gmsm-tunnel: #1, INSTALLED, TUNNEL
    ESP:SM4_CBC-128/HMAC_SM3_96
```

---

## 🐛 当前遗留问题

### 1. 客户端服务器 (8.140.37.32) 无法访问
**现象**: ping 和 SSH 都超时

**可能原因**:
- 阿里云安全组触发防护策略
- 容器配置错误导致网络问题
- 短时间内频繁 SSH 连接被限制

**解决方案**:
- 选项 A: 等待 10-15 分钟自动解除
- 选项 B: 通过阿里云控制台 VNC 连接
- 选项 C: 通过阿里云控制台重启实例
- 选项 D: 先测试服务器端，客户端稍后处理

**当前策略**: 选项 D - 先完成服务器端测试

---

## 📊 测试进度表

| 任务 | 状态 | 说明 |
|------|------|------|
| 发现问题根因 | ✅ | proposal 关键字未生成到运行时代码 |
| 修复 gmsm_plugin.c | ✅ | 添加 VERSION 宏 |
| 修复 crypter.c | ✅ | 添加 SM4 名称映射 |
| 修复 Dockerfile | ✅ | 使用本地代码 + autoreconf |
| 转换换行符 | ✅ | git-version 脚本 |
| 重新编译镜像 | 🔄 | 进行中 (3-5 分钟) |
| 上传到服务器 | ⏳ | 待编译完成 |
| 测试服务器端配置 | ⏳ | 待上传完成 |
| 恢复客户端访问 | ⏳ | 等待自动恢复或手动处理 |
| 测试国密 VPN | ⏳ | 待双端就绪 |

---

## 💡 技术收获

### 1. strongSwan 的配置解析流程
```
proposal_keywords_static.txt
          ↓ (gperf 工具)
proposal_keywords_static.c
          ↓ (编译)
配置文件关键字查找
          ↓
算法标识符 (ENCR_SM4_CBC)
          ↓ (插件提供)
实际加密实现 (GmSSL)
```

### 2. Docker 构建优化
- 使用多阶段构建减小镜像体积
- 合理安排层次避免不必要的重新构建
- COPY 本地代码而不是 git clone

### 3. 跨平台问题处理
- Windows 换行符 (CRLF) vs Linux (LF)
- 使用 dos2unix 或 PowerShell 转换
- 在 Dockerfile 中处理兼容性

---

**下一步**: 等待编译完成 (~2 分钟剩余)
