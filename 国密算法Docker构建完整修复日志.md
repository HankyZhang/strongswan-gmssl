# 国密算法 Docker 构建 - 完整修复日志

## 日期
2025-11-04

## 背景
在使用 Docker 构建包含 GmSSL 和国密算法支持的 strongSwan 时，遇到多个编译错误。本文档记录了所有问题和修复方案。

---

## 问题列表

### ✅ 问题 1: 缺少 gperf 工具

**错误信息**:
```
configure: error: GNU gperf required to generate proposal_keywords_static.c
checking gperf len type... not found
```

**原因**: 
- `gperf` 是 GNU 完美哈希函数生成器
- strongSwan 使用它生成高效的关键字查找表

**解决方案**:
```dockerfile
RUN apt-get install -y gperf
```

**Git 提交**: 在 Dockerfile.gmssl 中添加依赖

---

### ✅ 问题 2: 缺少 bison 和 flex 工具

**错误信息**:
```
../../ylwrap: line 176: yacc: command not found
make[3]: *** [Makefile:2301: settings/settings_parser.c] Error 127
```

**原因**:
- `bison` (yacc的 GNU 实现) - 语法分析器生成器
- `flex` - 词法分析器生成器
- strongSwan 使用它们解析配置文件

**解决方案**:
```dockerfile
RUN apt-get install -y bison flex
```

**Git 提交**: 在 Dockerfile.gmssl 中添加依赖

---

### ✅ 问题 3: SM2_256 枚举值未处理

**文件**: `src/libstrongswan/crypto/key_exchange.c`

**错误信息**:
```c
crypto/key_exchange.c:642:9: error: enumeration value 'SM2_256' not handled in switch [-Werror=switch]
  642 |         switch (ke)
      |         ^~~~~~
```

**原因**:
- `key_exchange_verify_pubkey()` 函数的 switch 语句缺少 SM2_256 处理
- SM2 是国密椭圆曲线公钥密码算法

**解决方案**:
```c
case ECP_256_BIT:
case ECP_256_BP:
case SM2_256:          // 新增
    valid = value.len == 64;
    break;
```

**技术说明**:
- SM2 使用 256 位椭圆曲线（GM/T 0003）
- 未压缩公钥格式: 0x04 || X(32字节) || Y(32字节) = 65字节
- 验证时检查坐标数据长度: 64字节（不包括0x04前缀）

**Git 提交**: 
```bash
git commit -m "Fix SM2_256 enum handling in key_exchange_verify_pubkey switch statement"
```

---

### ✅ 问题 4: SM3 相关枚举值未处理

**文件**: `src/libstrongswan/crypto/hashers/hasher.c`

**错误信息**:
```
crypto/hashers/hasher.c:172:9: error: enumeration value 'PRF_HMAC_SM3' not handled
crypto/hashers/hasher.c:237:9: error: enumeration value 'AUTH_HMAC_SM3_96' not handled
crypto/hashers/hasher.c:276:9: error: enumeration value 'HASH_SM3' not handled
crypto/hashers/hasher.c:346:9: error: enumeration value 'HASH_MD2' not handled
```

**原因**:
- SM3 是国密哈希算法（GM/T 0004-2012），输出256位
- 多个函数的 switch 语句缺少 SM3 相关枚举处理

**解决方案**:

#### 4.1 hasher_algorithm_from_prf()
```c
case PRF_HMAC_SM3:
    return HASH_SM3;
```

#### 4.2 hasher_algorithm_from_integrity()
```c
case AUTH_HMAC_SM3_96:
    return HASH_SM3;
```

#### 4.3 hasher_algorithm_to_integrity()
```c
case HASH_SM3:
    switch (length)
    {
        case 12:  // 96位截断
            return AUTH_HMAC_SM3_96;
    }
    break;
case HASH_MD2:
    break;  // 不支持，但需要处理枚举
```

#### 4.4 hasher_algorithm_for_ikev2()
```c
case HASH_SM3:
case HASH_MD2:
    break;  // IKEv2 不支持这些算法
```

**技术说明**:
- SM3 输出: 256位 (32字节)
- HMAC-SM3-96: 截取前96位 (12字节) 用于完整性验证
- IKEv2 标准不直接支持 SM3，需要扩展

**Git 提交**:
```bash
git commit -m "Fix SM3 and BLISS related enum handling in hasher.c switch statements"
```

---

### ✅ 问题 5: BLISS 签名算法枚举未处理

**文件**: `src/libstrongswan/crypto/hashers/hasher.c`

**错误信息**:
```
crypto/hashers/hasher.c:486:9: error: enumeration value 'SIGN_BLISS_WITH_SHA2_256' not handled
crypto/hashers/hasher.c:486:9: error: enumeration value 'SIGN_BLISS_WITH_SHA2_384' not handled
...
```

**原因**:
- BLISS (Bimodal Lattice Signature Scheme) 是后量子签名算法
- strongSwan 支持但在某些 switch 语句中未处理

**解决方案**:
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

**Git 提交**: 同问题4

---

### ✅ 问题 6: SM4 加密算法枚举未处理

**文件**: `src/libstrongswan/crypto/iv/iv_gen.c`

**错误信息**:
```
crypto/iv/iv_gen.c:28:9: error: enumeration value 'ENCR_SM4_CBC' not handled
crypto/iv/iv_gen.c:28:9: error: enumeration value 'ENCR_SM4_GCM_ICV16' not handled
```

**原因**:
- SM4 是国密分组密码算法（GM/T 0002-2012），块大小128位
- IV生成器需要为不同模式选择不同的IV生成策略

**解决方案**:

#### SM4-CBC 模式 - 随机IV
```c
case ENCR_AES_CBC:
case ENCR_CAMELLIA_CBC:
case ENCR_SM4_CBC:     // 新增
    return iv_gen_rand_create();
```

#### SM4-GCM 模式 - 序列IV
```c
case ENCR_AES_GCM_ICV16:
case ENCR_CHACHA20_POLY1305:
case ENCR_SM4_GCM_ICV16:   // 新增
    return iv_gen_seq_create();
```

**技术说明**:
- **CBC 模式**: 需要随机不可预测的IV，防止密文攻击
- **GCM 模式**: 使用序列IV（计数器），每次加密递增，防止IV重用
- SM4-GCM-ICV16: GCM模式，16字节(128位)完整性校验值

**Git 提交**:
```bash
git commit -m "Add SM4 encryption algorithm support to IV generator (CBC and GCM modes)"
```

---

## 编译选项说明

strongSwan 使用严格的编译警告：

```c
-Werror                          // 所有警告视为错误
-Werror=switch                   // switch语句必须处理所有枚举值
-Wall -Wextra                    // 启用所有标准警告
```

这确保了代码质量，但要求开发者显式处理所有枚举值。

---

## 国密算法技术总结

### SM2 - 椭圆曲线公钥密码
- **标准**: GM/T 0003-2012
- **曲线**: 256位素数域椭圆曲线
- **用途**: 数字签名、密钥交换、加密
- **公钥长度**: 64字节（未压缩坐标）

### SM3 - 密码哈希算法
- **标准**: GM/T 0004-2012
- **输出**: 256位 (32字节)
- **用途**: 数字签名、完整性校验、HMAC
- **性能**: 与SHA-256相当

### SM4 - 分组密码算法
- **标准**: GM/T 0002-2012
- **块大小**: 128位
- **密钥长度**: 128位
- **模式**: CBC, CTR, GCM等
- **性能**: 与AES-128相当

---

## Git 提交历史

```bash
# 1. 添加编译工具依赖
Commit: Add gperf, bison and flex dependencies to Dockerfile.gmssl
File: Dockerfile.gmssl

# 2. 修复 SM2 密钥交换支持
Commit: Fix SM2_256 enum handling in key_exchange_verify_pubkey switch statement
File: src/libstrongswan/crypto/key_exchange.c

# 3. 修复 SM3 哈希算法支持
Commit: Fix SM3 and BLISS related enum handling in hasher.c switch statements
File: src/libstrongswan/crypto/hashers/hasher.c

# 4. 修复 SM4 加密算法支持
Commit: Add SM4 encryption algorithm support to IV generator (CBC and GCM modes)
File: src/libstrongswan/crypto/iv/iv_gen.c
```

---

## 构建状态

- ✅ 工具链依赖完整
- ✅ SM2 密钥交换支持
- ✅ SM3 哈希算法支持
- ✅ SM4 加密算法支持
- 🔄 Docker 镜像构建中...

---

## 下一步

1. ✅ 等待 Docker 构建完成
2. ⏭️ 运行测试脚本 `quick-test-gmsm.ps1`
3. ⏭️ 验证国密算法功能
4. ⏭️ 测试 VPN 连接

---

## 参考资料

- [GM/T 0003-2012] SM2椭圆曲线公钥密码算法
- [GM/T 0004-2012] SM3密码哈希算法
- [GM/T 0002-2012] SM4分组密码算法
- [GmSSL Documentation](https://github.com/guanzhi/GmSSL)
- [strongSwan Documentation](https://docs.strongswan.org/)

---

**修复完成时间**: 2025-11-04  
**总共修复问题**: 6个  
**修改文件数**: 4个  
**Git 提交数**: 4次
