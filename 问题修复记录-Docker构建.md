# 问题修复记录 - Docker 构建国密算法集成

## 日期
2025-11-04

## 问题描述

在使用 Docker 构建包含国密算法支持的 strongSwan 时遇到了编译错误。

## 遇到的问题及解决方案

### 问题 1: 缺少 gperf 工具

**错误信息**:
```
configure: error: GNU gperf required to generate e.g. ./src/libstrongswan/crypto/proposal/proposal_keywords_static.c
checking gperf len type... not found
```

**原因**: Dockerfile 中未安装 `gperf` 工具

**解决方案**: 在 Dockerfile.gmssl 的依赖安装部分添加 `gperf`:
```dockerfile
RUN apt-get update && apt-get install -y \
    ...
    gperf \
    ...
```

### 问题 2: 缺少 bison 和 flex 工具

**错误信息**:
```
../../ylwrap: line 176: yacc: command not found
make[3]: *** [Makefile:2301: settings/settings_parser.c] Error 127
```

**原因**: Dockerfile 中未安装 `bison` (yacc 的实现) 和 `flex`

**解决方案**: 在 Dockerfile.gmssl 中添加:
```dockerfile
RUN apt-get update && apt-get install -y \
    ...
    gperf \
    bison \
    flex \
    ...
```

### 问题 3: SM2_256 枚举值未处理

**错误信息**:
```
crypto/key_exchange.c:642:9: error: enumeration value 'SM2_256' not handled in switch [-Werror=switch]
  642 |         switch (ke)
      |         ^~~~~~
cc1: all warnings being treated as errors
make[5]: *** [Makefile:2290: crypto/key_exchange.lo] Error 1
```

**原因**: 在 `src/libstrongswan/crypto/key_exchange.c` 文件的 `key_exchange_verify_pubkey()` 函数中，switch 语句缺少对 `SM2_256` 枚举值的处理。由于编译时启用了 `-Werror=switch`，所有警告都被视为错误。

**解决方案**: 在 `key_exchange.c` 的 switch 语句中添加 `SM2_256` 的处理：

```c
case ECP_256_BIT:
case ECP_256_BP:
case SM2_256:          // 新增这一行
    valid = value.len == 64;
    break;
```

**说明**: SM2 使用 256 位曲线，公钥长度为 64 字节（未压缩格式：0x04 + 32字节X + 32字节Y），与其他 256 位椭圆曲线相同。

### 问题 4: SM3 和 BLISS 相关枚举值未处理

**错误信息**:
```
crypto/hashers/hasher.c:172:9: error: enumeration value 'PRF_HMAC_SM3' not handled in switch [-Werror=switch]
crypto/hashers/hasher.c:237:9: error: enumeration value 'AUTH_HMAC_SM3_96' not handled in switch [-Werror=switch]
crypto/hashers/hasher.c:276:9: error: enumeration value 'HASH_MD2' not handled in switch [-Werror=switch]
crypto/hashers/hasher.c:276:9: error: enumeration value 'HASH_SM3' not handled in switch [-Werror=switch]
crypto/hashers/hasher.c:346:9: error: enumeration value 'HASH_SM3' not handled in switch [-Werror=switch]
crypto/hashers/hasher.c:486:9: error: enumeration value 'SIGN_BLISS_WITH_SHA2_256' not handled in switch [-Werror=switch]
...
```

**原因**: `src/libstrongswan/crypto/hashers/hasher.c` 中多个函数的 switch 语句缺少对国密 SM3 相关枚举和 BLISS 签名算法枚举的处理。

**解决方案**: 在 `hasher.c` 的多个函数中添加相应枚举处理：

1. **hasher_algorithm_from_prf()** - 添加 PRF_HMAC_SM3 处理：
```c
case PRF_HMAC_SM3:
    return HASH_SM3;
```

2. **hasher_algorithm_from_integrity()** - 添加 AUTH_HMAC_SM3_96 处理：
```c
case AUTH_HMAC_SM3_96:
    return HASH_SM3;
```

3. **hasher_algorithm_to_integrity()** - 添加 HASH_SM3 和 HASH_MD2 处理：
```c
case HASH_SM3:
    switch (length)
    {
        case 12:
            return AUTH_HMAC_SM3_96;
    }
    break;
case HASH_MD2:
    /* not handled, fall through */
    break;
```

4. **hasher_algorithm_for_ikev2()** - 添加 HASH_SM3 和 HASH_MD2：
```c
case HASH_SM3:
case HASH_MD2:
    break;  // 不支持用于 IKEv2
```

5. **hasher_from_signature_scheme()** - 添加 BLISS 签名算法：
```c
case SIGN_BLISS_WITH_SHA2_256:
case SIGN_BLISS_WITH_SHA2_384:
case SIGN_BLISS_WITH_SHA2_512:
case SIGN_BLISS_WITH_SHA3_256:
case SIGN_BLISS_WITH_SHA3_384:
case SIGN_BLISS_WITH_SHA3_512:
    /* not handled, fall through */
    break;
```

**说明**: SM3 是中国国家密码局发布的密码哈希算法（GM/T 0004-2012），输出长度为 256 位（32 字节）。HMAC-SM3-96 截取前 96 位（12 字节）用作完整性校验。

## 修复后的完整依赖列表

```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    autoconf \
    automake \
    libtool \
    pkg-config \
    gperf \           # 用于生成完美哈希函数
    bison \           # 语法分析器生成器
    flex \            # 词法分析器生成器
    libpam0g-dev \
    libssl-dev \
    libgmp3-dev \
    libsystemd-dev \
    libcurl4-openssl-dev \
    libcap-ng-dev \
    gettext \
    iptables \
    iproute2 \
    net-tools \
    vim \
    iputils-ping \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

## 技术说明

### SM2 密钥长度

SM2 使用 256 位椭圆曲线（基于 GM/T 0003），公钥有两种格式：

1. **未压缩格式** (64 字节): `0x04 || X || Y`
   - 前缀: 0x04 (1 字节)
   - X 坐标: 32 字节
   - Y 坐标: 32 字节
   - 总计: 65 字节（包括前缀）或 64 字节（不包括前缀）

2. **压缩格式** (32 字节): `0x02/0x03 || X`
   - 前缀: 0x02 或 0x03 (1 字节)
   - X 坐标: 32 字节
   - 总计: 33 字节

在 strongSwan 中，`key_exchange_verify_pubkey()` 验证的是不包括格式前缀的坐标数据，因此 SM2_256 的验证长度为 64 字节。

## 编译选项说明

strongSwan 使用严格的编译警告选项：

```
-Werror                          # 将所有警告视为错误
-Wall                            # 启用所有常见警告
-Wextra                          # 启用额外警告
-Wno-format                      # 禁用格式字符串警告
-Wno-format-security             # 禁用格式安全警告
-Wno-implicit-fallthrough        # 禁用隐式 fallthrough 警告
-Wno-missing-field-initializers  # 禁用缺失字段初始化警告
-Wno-pointer-sign                # 禁用指针符号警告
-Wno-sign-compare                # 禁用符号比较警告
-Wno-type-limits                 # 禁用类型限制警告
-Wno-unused-parameter            # 禁用未使用参数警告
```

特别是 `-Werror=switch` 会检查 switch 语句是否处理了枚举的所有值。

## 验证步骤

修复完成后的验证：

1. ✅ Dockerfile 依赖完整
2. ✅ GmSSL 编译成功
3. ✅ strongSwan 编译成功（包含 SM2_256 支持）
4. ✅ gmsm 插件编译成功
5. 🔄 Docker 镜像构建中...

## 下一步

1. 等待 Docker 镜像构建完成
2. 运行测试脚本验证国密算法功能
3. 测试 SM2 密钥生成和验证
4. 测试完整的 VPN 连接

## 相关文件

- `Dockerfile.gmssl` - Docker 镜像定义
- `src/libstrongswan/crypto/key_exchange.c` - 密钥交换验证代码
- `src/libstrongswan/plugins/gmsm/` - 国密插件源代码

## Git 提交

```bash
# 修复 1-2: 添加编译依赖
git commit -m "Add gperf, bison and flex dependencies to Dockerfile.gmssl"

# 修复 3: 处理 SM2_256 枚举
git commit -m "Fix SM2_256 enum handling in key_exchange_verify_pubkey switch statement"

# 修复 4: 处理 SM3 和 BLISS 枚举
git commit -m "Fix SM3 and BLISS related enum handling in hasher.c switch statements"
```

## 总结

所有编译问题已修复：
- ✅ 工具链依赖完整 (gperf, bison, flex)
- ✅ SM2_256 枚举正确处理
- ✅ SM3 相关所有枚举正确处理
- ✅ BLISS 签名算法枚举正确处理
- ✅ 代码已推送到远程仓库
- 🔄 Docker 镜像正在构建

预计构建时间：10-15 分钟（利用了缓存层）
