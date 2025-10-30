# strongSwan + GmSSL 国密算法集成实施计划

## 📋 目录

1. [项目概述](#1-项目概述)
2. [为什么选择GmSSL](#2-为什么选择gmssl)
3. [总体架构设计](#3-总体架构设计)
4. [详细实施计划](#4-详细实施计划)
5. [测试验证计划](#5-测试验证计划)
6. [部署上线计划](#6-部署上线计划)

---

## 1. 项目概述

### 1.1 项目目标

在strongSwan VPN中集成中国国密算法（SM2/SM3/SM4），使其能够：
- ✅ 支持SM4对称加密（CBC/CTR/GCM模式）
- ✅ 支持SM3哈希算法和HMAC-SM3
- ✅ 支持SM2椭圆曲线密钥交换和数字签名
- ✅ 完全兼容现有的国际算法
- ✅ 符合国密局认证要求

### 1.2 技术方案

**采用插件化架构**，通过创建新的`gmssl`插件来实现国密算法支持：

```
strongSwan架构
    ↓
libstrongswan (核心库)
    ↓ 加载插件
┌─────────────────────────────────────┐
│ openssl插件 │ gmssl插件(新) │ ...   │
└─────────────────────────────────────┘
    ↓               ↓
OpenSSL库      GmSSL库(libgmssl.so)
```

**关键优势**：
- 🔹 无需修改strongSwan核心代码（90%以上）
- 🔹 利用成熟的GmSSL库，避免重复开发
- 🔹 插件化设计，可选择性启用
- 🔹 便于维护和升级

### 1.3 项目周期

| 阶段 | 周期 | 人力 |
|------|------|------|
| 环境准备和GmSSL编译 | 1周 | 1人 |
| gmssl插件开发 | 3-4周 | 2-3人 |
| 测试验证 | 2-3周 | 2人 |
| 文档编写和部署 | 1周 | 1人 |
| **总计** | **7-9周** | **2-3人** |

---

## 2. 为什么选择GmSSL

### 2.1 GmSSL vs 自行实现对比

| 维度 | 使用GmSSL | 自行实现 |
|------|-----------|----------|
| **开发工作量** | ~1000-1500行代码（适配层） | ~5000行代码（含算法） |
| **开发周期** | 3-4周 | 10-14周 |
| **算法正确性** | ✅ 国密局认证 | ⚠️ 需大量测试验证 |
| **性能优化** | ✅ 内置汇编优化 | ❌ 需手动优化 |
| **安全审计** | ✅ 已审计 | ⚠️ 需专业审计（成本高） |
| **维护成本** | 低（跟随GmSSL更新） | 高（需长期维护） |
| **认证合规** | ✅ 易于通过 | ⚠️ 需额外认证（时间长） |
| **社区支持** | ✅ 活跃社区 | ❌ 无社区支持 |

**结论**：**强烈推荐使用GmSSL库**

### 2.2 GmSSL技术优势

✅ **官方认证**
- 由北京大学关志教授团队开发
- 符合GM/T系列国家标准
- 经过国密局认证和测试

✅ **API友好**
- 类似OpenSSL的API设计
- strongSwan已有OpenSSL插件可参考
- 迁移成本低

✅ **性能优异**
- 针对SM2/SM3/SM4优化
- 支持硬件加速（AES-NI类似）
- 汇编级别优化

✅ **活跃维护**
- GitHub: https://github.com/guanzhi/GmSSL
- 3000+ stars，持续更新
- 丰富的文档和示例

---

## 3. 总体架构设计

### 3.1 插件架构

```
strongSwan插件系统
├─────────────────────────────────────────────────┐
│                                                 │
│   libstrongswan/crypto/crypto_factory.c         │
│   ├─ create_crypter()  → SM4加密器              │
│   ├─ create_hasher()   → SM3哈希                │
│   ├─ create_signer()   → HMAC-SM3               │
│   ├─ create_prf()      → PRF-HMAC-SM3           │
│   ├─ create_ke()       → SM2密钥交换            │
│   └─ create_public_key() → SM2公钥/签名         │
│                                                 │
└─────────────────────────────────────────────────┘
                    ↓ 插件注册
┌─────────────────────────────────────────────────┐
│   gmssl插件 (新创建)                             │
│   src/libstrongswan/plugins/gmssl/               │
│   ├─ gmssl_plugin.c       (插件入口)             │
│   ├─ gmssl_crypter.c      (SM4实现)              │
│   ├─ gmssl_hasher.c       (SM3实现)              │
│   ├─ gmssl_signer.c       (HMAC-SM3实现)         │
│   ├─ gmssl_prf.c          (PRF-HMAC-SM3实现)     │
│   ├─ gmssl_diffie_hellman.c (SM2-DH实现)        │
│   ├─ gmssl_ec_public_key.c  (SM2公钥/签名)      │
│   └─ gmssl_ec_private_key.c (SM2私钥/签名)      │
└─────────────────────────────────────────────────┘
                    ↓ 调用GmSSL API
┌─────────────────────────────────────────────────┐
│   GmSSL库 (libgmssl.so)                          │
│   ├─ SM4_encrypt/decrypt                         │
│   ├─ SM4_cbc_encrypt/decrypt                     │
│   ├─ SM4_ctr_encrypt                             │
│   ├─ SM4_gcm_encrypt/decrypt                     │
│   ├─ SM3_init/update/final                       │
│   ├─ SM3_hmac                                    │
│   ├─ SM2_compute_key                             │
│   ├─ SM2_sign/verify                             │
│   └─ SM2_encrypt/decrypt                         │
└─────────────────────────────────────────────────┘
```

### 3.2 算法映射关系

#### 3.2.1 对称加密算法（Crypter）

| strongSwan算法ID | 私有编号 | GmSSL API | 密钥长度 | IV长度 | 块大小 | 用途 |
|-----------------|---------|-----------|---------|--------|--------|------|
| `ENCR_SM4_CBC` | 1031 | `SM4_cbc_encrypt()` | 16字节 | 16字节 | 16字节 | IKE/ESP加密（CBC模式） |
| `ENCR_SM4_CTR` | 1033 | `SM4_ctr_encrypt()` | 16字节 | 16字节 | 1字节 | ESP加密（CTR模式） |
| `ENCR_SM4_GCM` | 1034 | `SM4_gcm_encrypt()` | 16字节 | 12字节 | 1字节 | ESP AEAD加密（含认证） |

**对应的GmSSL函数**：
```c
// CBC模式
void SM4_cbc_encrypt(const uint8_t *in, uint8_t *out, size_t len,
                     const SM4_KEY *key, uint8_t *iv, int enc);

// CTR模式
void SM4_ctr_encrypt(const uint8_t *in, uint8_t *out, size_t len,
                     const SM4_KEY *key, uint8_t *ctr);

// GCM模式
int SM4_gcm_encrypt(const SM4_KEY *key, const uint8_t *iv, size_t ivlen,
                    const uint8_t *aad, size_t aadlen,
                    const uint8_t *in, size_t inlen,
                    uint8_t *out, size_t taglen, uint8_t *tag);
```

#### 3.2.2 哈希算法（Hasher）

| strongSwan算法ID | 私有编号 | GmSSL API | 输出长度 | 块大小 | 用途 |
|-----------------|---------|-----------|---------|--------|------|
| `HASH_SM3` | 1027 | `SM3_init/update/final()` | 32字节 | 64字节 | 证书签名、哈希计算、密钥派生 |

**对应的GmSSL函数**：
```c
void SM3_init(SM3_CTX *ctx);
void SM3_update(SM3_CTX *ctx, const uint8_t *data, size_t len);
void SM3_final(SM3_CTX *ctx, uint8_t *digest);

// 便捷函数
void SM3(const uint8_t *data, size_t len, uint8_t *digest);
```

#### 3.2.3 完整性验证算法（Signer）

| strongSwan算法ID | 私有编号 | GmSSL API | 密钥长度 | 输出长度 | 用途 |
|-----------------|---------|-----------|---------|---------|------|
| `AUTH_HMAC_SM3_128` | 1013 | `SM3_hmac()` | 任意（推荐≥16） | 16字节 | ESP/IKE完整性验证（截断） |
| `AUTH_HMAC_SM3_256` | 1014 | `SM3_hmac()` | 任意（推荐≥32） | 32字节 | ESP/IKE完整性验证（完整） |

**对应的GmSSL函数**：
```c
void SM3_hmac(const uint8_t *key, size_t keylen,
              const uint8_t *data, size_t datalen,
              uint8_t *mac);

// 或使用HMAC上下文接口
void SM3_hmac_init(SM3_HMAC_CTX *ctx, const uint8_t *key, size_t keylen);
void SM3_hmac_update(SM3_HMAC_CTX *ctx, const uint8_t *data, size_t len);
void SM3_hmac_finish(SM3_HMAC_CTX *ctx, uint8_t *mac);
```

#### 3.2.4 伪随机函数（PRF）

| strongSwan算法ID | 私有编号 | 基于算法 | GmSSL API | 输出长度 | 用途 |
|-----------------|---------|---------|-----------|---------|------|
| `PRF_HMAC_SM3` | 1009 | HMAC-SM3 | `SM3_hmac()` | 32字节 | IKE密钥派生（SKEYSEED、SK_*） |

**对应的GmSSL函数**：
```c
// PRF使用HMAC-SM3实现
void SM3_hmac(const uint8_t *key, size_t keylen,
              const uint8_t *data, size_t datalen,
              uint8_t *mac);

// PRF+扩展函数（需在插件中实现）
// prf_plus(K, S) = T1 | T2 | T3 | ...
// T1 = PRF(K, S | 0x01)
// T2 = PRF(K, T1 | S | 0x02)
// T3 = PRF(K, T2 | S | 0x03)
```

#### 3.2.5 密钥交换方法（Key Exchange）

| strongSwan算法ID | 私有编号 | GmSSL API | 曲线参数 | 公钥长度 | 共享密钥长度 | 用途 |
|-----------------|---------|-----------|---------|---------|------------|------|
| `ECP_SM2` | 1041 | `SM2_compute_key()` | SM2推荐曲线 | 65字节（未压缩） | 32字节 | IKE_SA_INIT密钥交换 |

**对应的GmSSL函数**：
```c
// 生成密钥对
int SM2_key_generate(SM2_KEY *key);

// 获取公钥
int SM2_key_get_public_key(const SM2_KEY *key, uint8_t *out, size_t *outlen);

// ECDH密钥协商（简化版）
int SM2_compute_key(uint8_t *out, size_t *outlen,
                    const uint8_t *peer_pub, size_t peer_pub_len,
                    const SM2_KEY *key);

// 完整的SM2密钥交换协议（更复杂，需要多轮交互）
int SM2_kap_init(SM2_KAP_CTX *ctx, const SM2_KEY *key,
                 const char *id, size_t idlen);
int SM2_kap_exch(SM2_KAP_CTX *ctx, uint8_t *ephem_point, size_t *len);
int SM2_kap_compute_key(SM2_KAP_CTX *ctx, const uint8_t *peer_ephem_point,
                        size_t peer_len, const uint8_t *peer_pub, size_t peer_pub_len,
                        uint8_t *key, size_t keylen);
```

#### 3.2.6 公钥算法（Public Key）

| strongSwan密钥类型 | GmSSL API | 用途 | 支持的签名方案 |
|------------------|-----------|------|--------------|
| `KEY_SM2` | `SM2_KEY` | SM2椭圆曲线公钥/私钥 | `SIGN_SM2_WITH_SM3` |

**对应的GmSSL函数**：
```c
// 密钥生成
int SM2_key_generate(SM2_KEY *key);

// 从PEM/DER加载密钥
int SM2_private_key_from_pem(SM2_KEY *key, FILE *fp);
int SM2_public_key_from_pem(SM2_KEY *pub_key, FILE *fp);

// 签名（用于证书签名、IKE AUTH载荷）
int SM2_sign(const SM2_KEY *key, const uint8_t *dgst, size_t dgstlen,
             uint8_t *sig, size_t *siglen);

// 验证签名
int SM2_verify(const SM2_KEY *pub_key, const uint8_t *dgst, size_t dgstlen,
               const uint8_t *sig, size_t siglen);

// SM2加密/解密（可选，用于数据加密）
int SM2_encrypt(const SM2_KEY *pub_key, const uint8_t *in, size_t inlen,
                uint8_t *out, size_t *outlen);
int SM2_decrypt(const SM2_KEY *key, const uint8_t *in, size_t inlen,
                uint8_t *out, size_t *outlen);
```

#### 3.2.7 签名方案（Signature Scheme）

| strongSwan签名方案 | 私有编号 | 算法组合 | 用途 |
|------------------|---------|---------|------|
| `SIGN_SM2_WITH_SM3` | 待定 | SM2签名 + SM3哈希 | 证书签名、IKE认证、X.509证书 |

**签名流程**：
```c
// 1. 对消息计算SM3哈希
uint8_t hash[32];
SM3(message, message_len, hash);

// 2. 使用SM2私钥签名哈希值
uint8_t sig[72];  // SM2签名长度通常为64-72字节
size_t siglen;
SM2_sign(private_key, hash, 32, sig, &siglen);

// 3. 验证签名
int valid = SM2_verify(public_key, hash, 32, sig, siglen);
```

#### 3.2.8 国密算法在IPsec中的应用场景

| 协议阶段 | 算法类型 | 推荐算法 | strongSwan配置 |
|---------|---------|---------|---------------|
| **IKE_SA_INIT** | 加密算法 | SM4-CBC-128 | `ENCR_SM4_CBC` |
|  | 完整性算法 | HMAC-SM3-128 | `AUTH_HMAC_SM3_128` |
|  | PRF | PRF-HMAC-SM3 | `PRF_HMAC_SM3` |
|  | 密钥交换 | SM2 | `ECP_SM2` |
| **IKE_AUTH** | 签名验证 | SM2-SM3 | `SIGN_SM2_WITH_SM3` |
|  | 证书哈希 | SM3 | `HASH_SM3` |
| **CREATE_CHILD_SA** | ESP加密 | SM4-CBC/CTR/GCM | `ENCR_SM4_CBC/CTR/GCM` |
|  | ESP完整性 | HMAC-SM3-128 | `AUTH_HMAC_SM3_128` |
|  | PRF（重密钥） | PRF-HMAC-SM3 | `PRF_HMAC_SM3` |

#### 3.2.9 完整的配置提案映射

**IKE提案**：`sm4128-sm3-sm2`

```
展开为：
  - 加密算法: ENCR_SM4_CBC, 密钥长度=16字节
  - 完整性算法: AUTH_HMAC_SM3_128
  - PRF: PRF_HMAC_SM3
  - 密钥交换: ECP_SM2
```

**ESP提案**：`sm4128-sm3`

```
展开为：
  - 加密算法: ENCR_SM4_CBC, 密钥长度=16字节
  - 完整性算法: AUTH_HMAC_SM3_128
```

**ESP提案（AEAD模式）**：`sm4128gcm`

```
展开为：
  - 加密算法: ENCR_SM4_GCM, 密钥长度=16字节
  - 完整性算法: 无（GCM自带认证）
```

### 3.3 配置文件示例

**swanctl.conf（国密配置）**：
```conf
connections {
    gmssl-vpn {
        version = 2
        
        # 本地配置
        local {
            auth = pubkey
            certs = gmssl-cert.pem
            id = "C=CN, O=Example, CN=gateway"
        }
        
        # 远端配置
        remote {
            auth = pubkey
            id = "C=CN, O=Example, CN=client"
        }
        
        # IKE提案（国密）
        proposals = sm4128-sm3-sm2
        # 等同于：
        # - 加密: SM4-CBC-128
        # - 完整性: HMAC-SM3-128
        # - PRF: PRF-HMAC-SM3
        # - DH: SM2
        
        children {
            gmssl-tunnel {
                # ESP提案（国密）
                esp_proposals = sm4128-sm3
                # 等同于：
                # - 加密: SM4-CBC-128
                # - 完整性: HMAC-SM3-128
                
                local_ts = 10.1.0.0/24
                remote_ts = 10.2.0.0/24
            }
        }
    }
}
```

---

## 4. 详细实施计划

### 阶段1：环境准备（1周）

#### 1.1 安装GmSSL库

**步骤1：下载源码**
```bash
git clone https://github.com/guanzhi/GmSSL.git
cd GmSSL
git checkout v3.1.1  # 使用稳定版本
```

**步骤2：编译安装**
```bash
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local/gmssl
make -j4
sudo make install
```

**步骤3：验证安装**
```bash
# 检查库文件
ls -l /usr/local/gmssl/lib/libgmssl.so*

# 检查头文件
ls -l /usr/local/gmssl/include/gmssl/

# 测试SM4加密
gmssl sm4 -cbc -encrypt -in test.txt -out test.enc -key 0123456789ABCDEF
```

#### 1.2 strongSwan编译环境准备

```bash
cd /path/to/strongswan
./autogen.sh

./configure \
    --prefix=/usr/local/strongswan \
    --enable-gmssl \
    --with-gmssl-include=/usr/local/gmssl/include \
    --with-gmssl-lib=/usr/local/gmssl/lib \
    --enable-swanctl \
    --disable-stroke \
    --disable-scepclient

make clean
```

---

### 阶段2：扩展算法标识符（第1周）

#### 2.1 修改加密算法枚举

**文件**: `src/libstrongswan/crypto/crypters/crypter.h`

```c
// 在 enum encryption_algorithm_t 中添加：
enum encryption_algorithm_t {
    // ... 现有算法 ...
    ENCR_CHACHA20_POLY1305 = 28,
    
    /** 国密SM4算法（私有编号范围1024-2047） */
    ENCR_SM4_CBC = 1031,
    ENCR_SM4_CTR = 1033,
    ENCR_SM4_GCM = 1034,
};
```

**文件**: `src/libstrongswan/crypto/crypters/crypter.c`

```c
ENUM(encryption_algorithm_names, ENCR_UNDEFINED, ENCR_SM4_GCM,
    // ... 现有名称 ...
    "CHACHA20_POLY1305",
    // 1024-1030 预留
    "UNDEFINED", "UNDEFINED", "UNDEFINED", "UNDEFINED", "UNDEFINED",
    "UNDEFINED", "UNDEFINED",
    // 1031-1034 国密算法
    "SM4_CBC",
    "UNDEFINED",
    "SM4_CTR",
    "SM4_GCM",
);
```

#### 2.2 修改哈希算法枚举

**文件**: `src/libstrongswan/crypto/hashers/hasher.h`

```c
enum hash_algorithm_t {
    // ... 现有算法 ...
    HASH_SHA3_512 = 18,
    
    /** 国密SM3算法 */
    HASH_SM3 = 1027,
};
```

#### 2.3 修改签名算法枚举

**文件**: `src/libstrongswan/crypto/signers/signer.h`

```c
enum integrity_algorithm_t {
    // ... 现有算法 ...
    
    /** 国密HMAC-SM3 */
    AUTH_HMAC_SM3_128 = 1013,
    AUTH_HMAC_SM3_256 = 1014,
};
```

#### 2.4 修改PRF枚举

**文件**: `src/libstrongswan/crypto/prfs/prf.h`

```c
enum pseudo_random_function_t {
    // ... 现有算法 ...
    
    /** 国密PRF */
    PRF_HMAC_SM3 = 1009,
};
```

#### 2.5 修改DH群枚举

**文件**: `src/libstrongswan/crypto/key_exchange.h`

```c
enum key_exchange_method_t {
    // ... 现有方法 ...
    
    /** 国密SM2曲线 */
    ECP_SM2 = 1041,
};
```

---

### 阶段3：创建gmssl插件（第2-4周）

#### 3.1 创建插件目录结构

```bash
mkdir -p src/libstrongswan/plugins/gmssl
cd src/libstrongswan/plugins/gmssl

# 创建文件
touch gmssl_plugin.c gmssl_plugin.h
touch gmssl_crypter.c gmssl_crypter.h
touch gmssl_hasher.c gmssl_hasher.h
touch gmssl_signer.c gmssl_signer.h
touch gmssl_prf.c gmssl_prf.h
touch gmssl_diffie_hellman.c gmssl_diffie_hellman.h
touch gmssl_ec_public_key.c gmssl_ec_public_key.h
touch gmssl_ec_private_key.c gmssl_ec_private_key.h
touch Makefile.am
```

#### 3.2 实现插件主文件

**文件**: `src/libstrongswan/plugins/gmssl/gmssl_plugin.c`

```c
#include "gmssl_plugin.h"
#include "gmssl_crypter.h"
#include "gmssl_hasher.h"
#include "gmssl_signer.h"
#include "gmssl_prf.h"
#include "gmssl_diffie_hellman.h"
#include "gmssl_ec_public_key.h"
#include "gmssl_ec_private_key.h"

#include <library.h>
#include <gmssl/sm4.h>
#include <gmssl/sm3.h>
#include <gmssl/sm2.h>

typedef struct private_gmssl_plugin_t private_gmssl_plugin_t;

struct private_gmssl_plugin_t {
    gmssl_plugin_t public;
};

METHOD(plugin_t, get_name, char*,
    private_gmssl_plugin_t *this)
{
    return "gmssl";
}

METHOD(plugin_t, get_features, int,
    private_gmssl_plugin_t *this, plugin_feature_t *features[])
{
    static plugin_feature_t f[] = {
        /* SM4 加密算法 */
        PLUGIN_REGISTER(CRYPTER, gmssl_crypter_create),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CBC, 16),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CTR, 16),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_GCM, 16),
        
        /* SM3 哈希算法 */
        PLUGIN_REGISTER(HASHER, gmssl_hasher_create),
            PLUGIN_PROVIDE(HASHER, HASH_SM3),
        
        /* HMAC-SM3 签名算法 */
        PLUGIN_REGISTER(SIGNER, gmssl_signer_create),
            PLUGIN_PROVIDE(SIGNER, AUTH_HMAC_SM3_128),
            PLUGIN_PROVIDE(SIGNER, AUTH_HMAC_SM3_256),
        
        /* PRF-HMAC-SM3 */
        PLUGIN_REGISTER(PRF, gmssl_prf_create),
            PLUGIN_PROVIDE(PRF, PRF_HMAC_SM3),
        
        /* SM2 密钥交换 */
        PLUGIN_REGISTER(KE, gmssl_diffie_hellman_create),
            PLUGIN_PROVIDE(KE, ECP_SM2),
        
        /* SM2 公钥 */
        PLUGIN_REGISTER(PUBKEY, gmssl_ec_public_key_load, TRUE),
            PLUGIN_PROVIDE(PUBKEY, KEY_SM2),
            PLUGIN_PROVIDE(PUBKEY_SIGN, SIGN_SM2_WITH_SM3),
            PLUGIN_PROVIDE(PUBKEY_VERIFY, SIGN_SM2_WITH_SM3),
    };
    
    *features = f;
    return countof(f);
}

METHOD(plugin_t, destroy, void,
    private_gmssl_plugin_t *this)
{
    free(this);
}

plugin_t *gmssl_plugin_create()
{
    private_gmssl_plugin_t *this;
    
    INIT(this,
        .public = {
            .plugin = {
                .get_name = _get_name,
                .get_features = _get_features,
                .destroy = _destroy,
            },
        },
    );
    
    return &this->public.plugin;
}
```

#### 3.3 实现SM4加密器

**文件**: `src/libstrongswan/plugins/gmssl/gmssl_crypter.c`

```c
#include "gmssl_crypter.h"
#include <gmssl/sm4.h>
#include <library.h>

typedef struct private_gmssl_crypter_t private_gmssl_crypter_t;

struct private_gmssl_crypter_t {
    crypter_t public;
    
    int alg;
    size_t key_size;
    
    SM4_KEY encrypt_key;
    SM4_KEY decrypt_key;
};

METHOD(crypter_t, encrypt, bool,
    private_gmssl_crypter_t *this, chunk_t data, chunk_t iv,
    chunk_t *encrypted)
{
    u_char *in, *out;
    
    in = data.ptr;
    out = encrypted->ptr;
    
    if (encrypted->len < data.len)
    {
        return FALSE;
    }
    
    switch (this->alg)
    {
        case ENCR_SM4_CBC:
        {
            u_char iv_copy[SM4_BLOCK_SIZE];
            memcpy(iv_copy, iv.ptr, SM4_BLOCK_SIZE);
            SM4_cbc_encrypt(in, out, data.len, &this->encrypt_key,
                           iv_copy, 1);  // 1 = encrypt
            break;
        }
        case ENCR_SM4_CTR:
        {
            u_char ctr[SM4_BLOCK_SIZE];
            memcpy(ctr, iv.ptr, SM4_BLOCK_SIZE);
            SM4_ctr_encrypt(in, out, data.len, &this->encrypt_key, ctr);
            break;
        }
        case ENCR_SM4_GCM:
        {
            // GCM模式实现（需要额外的tag处理）
            // TODO: 实现GCM模式
            return FALSE;
        }
        default:
            return FALSE;
    }
    
    encrypted->len = data.len;
    return TRUE;
}

METHOD(crypter_t, decrypt, bool,
    private_gmssl_crypter_t *this, chunk_t data, chunk_t iv,
    chunk_t *decrypted)
{
    u_char *in, *out;
    
    in = data.ptr;
    out = decrypted->ptr;
    
    if (decrypted->len < data.len)
    {
        return FALSE;
    }
    
    switch (this->alg)
    {
        case ENCR_SM4_CBC:
        {
            u_char iv_copy[SM4_BLOCK_SIZE];
            memcpy(iv_copy, iv.ptr, SM4_BLOCK_SIZE);
            SM4_cbc_encrypt(in, out, data.len, &this->decrypt_key,
                           iv_copy, 0);  // 0 = decrypt
            break;
        }
        case ENCR_SM4_CTR:
        {
            u_char ctr[SM4_BLOCK_SIZE];
            memcpy(ctr, iv.ptr, SM4_BLOCK_SIZE);
            SM4_ctr_encrypt(in, out, data.len, &this->decrypt_key, ctr);
            break;
        }
        default:
            return FALSE;
    }
    
    decrypted->len = data.len;
    return TRUE;
}

METHOD(crypter_t, get_block_size, size_t,
    private_gmssl_crypter_t *this)
{
    return SM4_BLOCK_SIZE;  // 16 bytes
}

METHOD(crypter_t, get_iv_size, size_t,
    private_gmssl_crypter_t *this)
{
    return SM4_BLOCK_SIZE;  // 16 bytes
}

METHOD(crypter_t, get_key_size, size_t,
    private_gmssl_crypter_t *this)
{
    return this->key_size;
}

METHOD(crypter_t, set_key, bool,
    private_gmssl_crypter_t *this, chunk_t key)
{
    if (key.len != this->key_size)
    {
        return FALSE;
    }
    
    SM4_set_encrypt_key(&this->encrypt_key, key.ptr);
    SM4_set_decrypt_key(&this->decrypt_key, key.ptr);
    
    return TRUE;
}

METHOD(crypter_t, destroy, void,
    private_gmssl_crypter_t *this)
{
    memwipe(&this->encrypt_key, sizeof(SM4_KEY));
    memwipe(&this->decrypt_key, sizeof(SM4_KEY));
    free(this);
}

crypter_t *gmssl_crypter_create(encryption_algorithm_t algo,
                                 size_t key_size)
{
    private_gmssl_crypter_t *this;
    
    switch (algo)
    {
        case ENCR_SM4_CBC:
        case ENCR_SM4_CTR:
        case ENCR_SM4_GCM:
            if (key_size != 16)  // SM4 only supports 128-bit keys
            {
                return NULL;
            }
            break;
        default:
            return NULL;
    }
    
    INIT(this,
        .public = {
            .encrypt = _encrypt,
            .decrypt = _decrypt,
            .get_block_size = _get_block_size,
            .get_iv_size = _get_iv_size,
            .get_key_size = _get_key_size,
            .set_key = _set_key,
            .destroy = _destroy,
        },
        .alg = algo,
        .key_size = key_size,
    );
    
    return &this->public;
}
```

#### 3.4 实现SM3哈希

**文件**: `src/libstrongswan/plugins/gmssl/gmssl_hasher.c`

```c
#include "gmssl_hasher.h"
#include <gmssl/sm3.h>
#include <library.h>

typedef struct private_gmssl_hasher_t private_gmssl_hasher_t;

struct private_gmssl_hasher_t {
    hasher_t public;
    SM3_CTX ctx;
};

METHOD(hasher_t, get_hash, bool,
    private_gmssl_hasher_t *this, chunk_t chunk, uint8_t *hash)
{
    SM3_update(&this->ctx, chunk.ptr, chunk.len);
    
    if (hash)
    {
        SM3_CTX ctx_copy;
        memcpy(&ctx_copy, &this->ctx, sizeof(SM3_CTX));
        SM3_final(&ctx_copy, hash);
    }
    
    return TRUE;
}

METHOD(hasher_t, allocate_hash, bool,
    private_gmssl_hasher_t *this, chunk_t chunk, chunk_t *hash)
{
    if (hash)
    {
        *hash = chunk_alloc(SM3_DIGEST_SIZE);
        get_hash(this, chunk, hash->ptr);
    }
    else
    {
        get_hash(this, chunk, NULL);
    }
    
    return TRUE;
}

METHOD(hasher_t, get_hash_size, size_t,
    private_gmssl_hasher_t *this)
{
    return SM3_DIGEST_SIZE;  // 32 bytes
}

METHOD(hasher_t, reset, bool,
    private_gmssl_hasher_t *this)
{
    SM3_init(&this->ctx);
    return TRUE;
}

METHOD(hasher_t, destroy, void,
    private_gmssl_hasher_t *this)
{
    memwipe(&this->ctx, sizeof(SM3_CTX));
    free(this);
}

hasher_t *gmssl_hasher_create(hash_algorithm_t algo)
{
    private_gmssl_hasher_t *this;
    
    if (algo != HASH_SM3)
    {
        return NULL;
    }
    
    INIT(this,
        .public = {
            .get_hash = _get_hash,
            .allocate_hash = _allocate_hash,
            .get_hash_size = _get_hash_size,
            .reset = _reset,
            .destroy = _destroy,
        },
    );
    
    SM3_init(&this->ctx);
    
    return &this->public;
}
```

#### 3.5 实现HMAC-SM3

**文件**: `src/libstrongswan/plugins/gmssl/gmssl_signer.c`

```c
#include "gmssl_signer.h"
#include <gmssl/sm3.h>
#include <library.h>

#define SM3_HMAC_BLOCK_SIZE 64

typedef struct private_gmssl_signer_t private_gmssl_signer_t;

struct private_gmssl_signer_t {
    signer_t public;
    
    size_t truncation;
    
    uint8_t ipad[SM3_HMAC_BLOCK_SIZE];
    uint8_t opad[SM3_HMAC_BLOCK_SIZE];
};

METHOD(signer_t, get_signature, bool,
    private_gmssl_signer_t *this, chunk_t data, uint8_t *buffer)
{
    SM3_CTX ctx;
    uint8_t hash[SM3_DIGEST_SIZE];
    
    // 内部哈希: H(ipad || data)
    SM3_init(&ctx);
    SM3_update(&ctx, this->ipad, SM3_HMAC_BLOCK_SIZE);
    SM3_update(&ctx, data.ptr, data.len);
    SM3_final(&ctx, hash);
    
    // 外部哈希: H(opad || hash)
    SM3_init(&ctx);
    SM3_update(&ctx, this->opad, SM3_HMAC_BLOCK_SIZE);
    SM3_update(&ctx, hash, SM3_DIGEST_SIZE);
    SM3_final(&ctx, hash);
    
    memcpy(buffer, hash, this->truncation);
    
    return TRUE;
}

METHOD(signer_t, allocate_signature, bool,
    private_gmssl_signer_t *this, chunk_t data, chunk_t *signature)
{
    if (signature)
    {
        *signature = chunk_alloc(this->truncation);
        get_signature(this, data, signature->ptr);
    }
    else
    {
        uint8_t buffer[SM3_DIGEST_SIZE];
        get_signature(this, data, buffer);
    }
    
    return TRUE;
}

METHOD(signer_t, verify_signature, bool,
    private_gmssl_signer_t *this, chunk_t data, chunk_t signature)
{
    uint8_t sig[SM3_DIGEST_SIZE];
    
    if (signature.len != this->truncation)
    {
        return FALSE;
    }
    
    get_signature(this, data, sig);
    
    return memeq_const(signature.ptr, sig, this->truncation);
}

METHOD(signer_t, get_key_size, size_t,
    private_gmssl_signer_t *this)
{
    return SM3_HMAC_BLOCK_SIZE;
}

METHOD(signer_t, get_block_size, size_t,
    private_gmssl_signer_t *this)
{
    return SM3_DIGEST_SIZE;
}

METHOD(signer_t, set_key, bool,
    private_gmssl_signer_t *this, chunk_t key)
{
    int i;
    uint8_t k[SM3_HMAC_BLOCK_SIZE];
    
    memset(k, 0, SM3_HMAC_BLOCK_SIZE);
    
    if (key.len > SM3_HMAC_BLOCK_SIZE)
    {
        // 如果密钥太长，先哈希
        SM3_CTX ctx;
        SM3_init(&ctx);
        SM3_update(&ctx, key.ptr, key.len);
        SM3_final(&ctx, k);
    }
    else
    {
        memcpy(k, key.ptr, key.len);
    }
    
    // 计算 ipad 和 opad
    for (i = 0; i < SM3_HMAC_BLOCK_SIZE; i++)
    {
        this->ipad[i] = k[i] ^ 0x36;
        this->opad[i] = k[i] ^ 0x5c;
    }
    
    memwipe(k, SM3_HMAC_BLOCK_SIZE);
    
    return TRUE;
}

METHOD(signer_t, destroy, void,
    private_gmssl_signer_t *this)
{
    memwipe(this->ipad, SM3_HMAC_BLOCK_SIZE);
    memwipe(this->opad, SM3_HMAC_BLOCK_SIZE);
    free(this);
}

signer_t *gmssl_signer_create(integrity_algorithm_t algo)
{
    private_gmssl_signer_t *this;
    size_t truncation;
    
    switch (algo)
    {
        case AUTH_HMAC_SM3_128:
            truncation = 16;
            break;
        case AUTH_HMAC_SM3_256:
            truncation = 32;
            break;
        default:
            return NULL;
    }
    
    INIT(this,
        .public = {
            .get_signature = _get_signature,
            .allocate_signature = _allocate_signature,
            .verify_signature = _verify_signature,
            .get_key_size = _get_key_size,
            .get_block_size = _get_block_size,
            .set_key = _set_key,
            .destroy = _destroy,
        },
        .truncation = truncation,
    );
    
    return &this->public;
}
```

#### 3.6 实现PRF-HMAC-SM3

**文件**: `src/libstrongswan/plugins/gmssl/gmssl_prf.c`

```c
#include "gmssl_prf.h"
#include "gmssl_signer.h"
#include <library.h>

typedef struct private_gmssl_prf_t private_gmssl_prf_t;

struct private_gmssl_prf_t {
    prf_t public;
    signer_t *signer;
};

METHOD(prf_t, get_bytes, bool,
    private_gmssl_prf_t *this, chunk_t seed, uint8_t *buffer)
{
    return this->signer->get_signature(this->signer, seed, buffer);
}

METHOD(prf_t, allocate_bytes, bool,
    private_gmssl_prf_t *this, chunk_t seed, chunk_t *chunk)
{
    if (chunk)
    {
        *chunk = chunk_alloc(this->signer->get_block_size(this->signer));
        return get_bytes(this, seed, chunk->ptr);
    }
    
    return get_bytes(this, seed, NULL);
}

METHOD(prf_t, get_block_size, size_t,
    private_gmssl_prf_t *this)
{
    return this->signer->get_block_size(this->signer);
}

METHOD(prf_t, get_key_size, size_t,
    private_gmssl_prf_t *this)
{
    return this->signer->get_key_size(this->signer);
}

METHOD(prf_t, set_key, bool,
    private_gmssl_prf_t *this, chunk_t key)
{
    return this->signer->set_key(this->signer, key);
}

METHOD(prf_t, destroy, void,
    private_gmssl_prf_t *this)
{
    this->signer->destroy(this->signer);
    free(this);
}

prf_t *gmssl_prf_create(pseudo_random_function_t algo)
{
    private_gmssl_prf_t *this;
    
    if (algo != PRF_HMAC_SM3)
    {
        return NULL;
    }
    
    INIT(this,
        .public = {
            .get_bytes = _get_bytes,
            .allocate_bytes = _allocate_bytes,
            .get_block_size = _get_block_size,
            .get_key_size = _get_key_size,
            .set_key = _set_key,
            .destroy = _destroy,
        },
        .signer = gmssl_signer_create(AUTH_HMAC_SM3_256),
    );
    
    if (!this->signer)
    {
        free(this);
        return NULL;
    }
    
    return &this->public;
}
```

#### 3.7 实现SM2密钥交换（简化版）

**文件**: `src/libstrongswan/plugins/gmssl/gmssl_diffie_hellman.c`

```c
#include "gmssl_diffie_hellman.h"
#include <gmssl/sm2.h>
#include <library.h>

typedef struct private_gmssl_dh_t private_gmssl_dh_t;

struct private_gmssl_dh_t {
    key_exchange_t public;
    
    SM2_KEY sm2_key;
    chunk_t my_public_value;
    chunk_t shared_secret;
};

METHOD(key_exchange_t, get_public_key, bool,
    private_gmssl_dh_t *this, chunk_t *value)
{
    *value = chunk_clone(this->my_public_value);
    return TRUE;
}

METHOD(key_exchange_t, set_public_key, bool,
    private_gmssl_dh_t *this, chunk_t value)
{
    uint8_t secret[32];
    size_t secret_len;
    
    // 使用GmSSL的SM2密钥交换函数
    // 注意：这是简化版本，实际需要更复杂的协商过程
    if (SM2_compute_key(secret, &secret_len, value.ptr, value.len,
                        &this->sm2_key) != 1)
    {
        return FALSE;
    }
    
    this->shared_secret = chunk_clone(chunk_from_thing(secret));
    memwipe(secret, sizeof(secret));
    
    return TRUE;
}

METHOD(key_exchange_t, get_shared_secret, bool,
    private_gmssl_dh_t *this, chunk_t *secret)
{
    if (!this->shared_secret.ptr)
    {
        return FALSE;
    }
    
    *secret = chunk_clone(this->shared_secret);
    return TRUE;
}

METHOD(key_exchange_t, get_method, key_exchange_method_t,
    private_gmssl_dh_t *this)
{
    return ECP_SM2;
}

METHOD(key_exchange_t, destroy, void,
    private_gmssl_dh_t *this)
{
    chunk_clear(&this->my_public_value);
    chunk_clear(&this->shared_secret);
    memwipe(&this->sm2_key, sizeof(SM2_KEY));
    free(this);
}

key_exchange_t *gmssl_diffie_hellman_create(key_exchange_method_t method)
{
    private_gmssl_dh_t *this;
    uint8_t public_key[65];
    size_t public_key_len;
    
    if (method != ECP_SM2)
    {
        return NULL;
    }
    
    INIT(this,
        .public = {
            .get_public_key = _get_public_key,
            .set_public_key = _set_public_key,
            .get_shared_secret = _get_shared_secret,
            .get_method = _get_method,
            .destroy = _destroy,
        },
    );
    
    // 生成SM2密钥对
    if (SM2_key_generate(&this->sm2_key) != 1)
    {
        free(this);
        return NULL;
    }
    
    // 获取公钥
    if (SM2_key_get_public_key(&this->sm2_key, public_key,
                                &public_key_len) != 1)
    {
        free(this);
        return NULL;
    }
    
    this->my_public_value = chunk_clone(chunk_create(public_key,
                                                       public_key_len));
    
    return &this->public;
}
```

#### 3.8 配置Makefile.am

**文件**: `src/libstrongswan/plugins/gmssl/Makefile.am`

```makefile
AM_CPPFLAGS = \
    -I$(top_srcdir)/src/libstrongswan \
    -I@GMSSL_INCLUDE@

AM_CFLAGS = \
    $(PLUGIN_CFLAGS)

AM_LDFLAGS = \
    -L@GMSSL_LIB@ -lgmssl

if MONOLITHIC
noinst_LTLIBRARIES = libstrongswan-gmssl.la
else
plugin_LTLIBRARIES = libstrongswan-gmssl.la
endif

libstrongswan_gmssl_la_SOURCES = \
    gmssl_plugin.h gmssl_plugin.c \
    gmssl_crypter.h gmssl_crypter.c \
    gmssl_hasher.h gmssl_hasher.c \
    gmssl_signer.h gmssl_signer.c \
    gmssl_prf.h gmssl_prf.c \
    gmssl_diffie_hellman.h gmssl_diffie_hellman.c \
    gmssl_ec_public_key.h gmssl_ec_public_key.c \
    gmssl_ec_private_key.h gmssl_ec_private_key.c

libstrongswan_gmssl_la_LDFLAGS = -module -avoid-version -no-undefined
```

---

### 阶段4：配置构建系统（第4周）

#### 4.1 修改configure.ac

**文件**: `configure.ac`

在适当位置添加：

```bash
# GmSSL plugin
ARG_ENABLE_SET([gmssl],
    [enables the GmSSL crypto plugin (SM2/SM3/SM4).])
if test x$gmssl = xtrue; then
    AC_HAVE_LIBRARY([gmssl],[LIBS="$LIBS"],[AC_MSG_ERROR([GmSSL library not found])])
    AC_CHECK_HEADER([gmssl/sm4.h],,[AC_MSG_ERROR([gmssl/sm4.h not found!])])
fi
AM_CONDITIONAL(USE_GMSSL, test x$gmssl = xtrue)

# GmSSL include/lib paths
AC_ARG_WITH([gmssl-include],
    AS_HELP_STRING([--with-gmssl-include=PATH], [GmSSL include directory]),
    [GMSSL_INCLUDE="$withval"],
    [GMSSL_INCLUDE="/usr/local/gmssl/include"])
AC_SUBST(GMSSL_INCLUDE)

AC_ARG_WITH([gmssl-lib],
    AS_HELP_STRING([--with-gmssl-lib=PATH], [GmSSL library directory]),
    [GMSSL_LIB="$withval"],
    [GMSSL_LIB="/usr/local/gmssl/lib"])
AC_SUBST(GMSSL_LIB)
```

#### 4.2 修改src/libstrongswan/plugins/Makefile.am

添加gmssl子目录：

```makefile
if USE_GMSSL
  SUBDIRS += gmssl
endif
```

#### 4.3 重新生成配置

```bash
./autogen.sh

./configure \
    --prefix=/usr/local/strongswan \
    --enable-gmssl \
    --with-gmssl-include=/usr/local/gmssl/include \
    --with-gmssl-lib=/usr/local/gmssl/lib \
    --enable-swanctl \
    --sysconfdir=/etc

make -j4
sudo make install
```

---

## 5. 测试验证计划

### 5.1 单元测试（第5周）

#### 测试SM4加密

```c
// tests/suites/test_gmssl_crypter.c
START_TEST(test_sm4_cbc_encrypt)
{
    crypter_t *crypter;
    chunk_t key, iv, plain, encrypted, decrypted;
    
    key = chunk_from_chars(
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
    );
    
    iv = chunk_from_chars(
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    );
    
    plain = chunk_from_str("Hello SM4 World!");
    
    crypter = lib->crypto->create_crypter(lib->crypto,
                                           ENCR_SM4_CBC, 16);
    ck_assert(crypter != NULL);
    ck_assert(crypter->set_key(crypter, key));
    
    encrypted = chunk_alloca(plain.len);
    ck_assert(crypter->encrypt(crypter, plain, iv, &encrypted));
    
    decrypted = chunk_alloca(encrypted.len);
    ck_assert(crypter->decrypt(crypter, encrypted, iv, &decrypted));
    
    ck_assert(chunk_equals(plain, decrypted));
    
    crypter->destroy(crypter);
}
END_TEST
```

#### 测试SM3哈希

```c
START_TEST(test_sm3_hash)
{
    hasher_t *hasher;
    chunk_t data, hash;
    uint8_t expected[] = {
        // SM3("abc") 的标准哈希值
        0x66, 0xc7, 0xf0, 0xf4, 0x62, 0xee, 0xed, 0xd9,
        0xd1, 0xf2, 0xd4, 0x6b, 0xdc, 0x10, 0xe4, 0xe2,
        0x41, 0x67, 0xc4, 0x87, 0x5c, 0xf2, 0xf7, 0xa2,
        0x29, 0x7d, 0xa0, 0x2b, 0x8f, 0x4b, 0xa8, 0xe0
    };
    
    data = chunk_from_str("abc");
    
    hasher = lib->crypto->create_hasher(lib->crypto, HASH_SM3);
    ck_assert(hasher != NULL);
    
    ck_assert(hasher->allocate_hash(hasher, data, &hash));
    ck_assert(hash.len == 32);
    ck_assert(memeq(hash.ptr, expected, 32));
    
    chunk_free(&hash);
    hasher->destroy(hasher);
}
END_TEST
```

### 5.2 集成测试（第6周）

#### 测试IKE_SA_INIT协商

**配置文件**: `testing/tests/gmssl/ikev2-sm4-sm3/hosts/moon/etc/swanctl/swanctl.conf`

```conf
connections {
    gmssl-test {
        version = 2
        
        local {
            auth = pubkey
            certs = moon-sm2.pem
            id = "C=CN, O=Test, CN=moon"
        }
        
        remote {
            auth = pubkey
            id = "C=CN, O=Test, CN=sun"
        }
        
        # 国密IKE提案
        proposals = sm4128-sm3-sm2
        
        children {
            net {
                # 国密ESP提案
                esp_proposals = sm4128-sm3
                
                local_ts = 10.1.0.0/16
                remote_ts = 10.2.0.0/16
            }
        }
    }
}
```

**测试脚本**:
```bash
#!/bin/bash

# 启动strongSwan
swanctl --load-all

# 发起连接
swanctl --initiate --child net

# 检查SA状态
swanctl --list-sas

# 验证提案选择
if swanctl --list-sas | grep -q "SM4_CBC"; then
    echo "✓ SM4加密算法协商成功"
else
    echo "✗ SM4加密算法协商失败"
    exit 1
fi

if swanctl --list-sas | grep -q "HMAC_SM3"; then
    echo "✓ HMAC-SM3完整性算法协商成功"
else
    echo "✗ HMAC-SM3完整性算法协商失败"
    exit 1
fi

# 测试数据传输
ping -c 4 10.2.0.1

echo "测试完成"
```

### 5.3 性能测试（第6-7周）

```bash
# SM4 vs AES性能对比
scripts/pubkey_speed.sh

# 测试吞吐量
iperf3 -s  # 在服务端
iperf3 -c server_ip  # 在客户端
```

---

## 6. 部署上线计划

### 6.1 生成SM2证书

```bash
# 生成CA私钥和证书
gmssl sm2keygen -out ca-key.pem
gmssl certgen -C CN -ST Beijing -L Beijing -O "Test CA" \
    -CN "Test Root CA" -key ca-key.pem -out ca-cert.pem

# 生成服务端证书
gmssl sm2keygen -out server-key.pem
gmssl certreq -C CN -ST Beijing -L Beijing -O "Test Org" \
    -CN "vpn.example.com" -key server-key.pem -out server-req.pem
gmssl certsign -in server-req.pem -cacert ca-cert.pem \
    -cakey ca-key.pem -out server-cert.pem

# 复制到strongSwan目录
cp server-cert.pem /etc/swanctl/x509/
cp server-key.pem /etc/swanctl/private/
cp ca-cert.pem /etc/swanctl/x509ca/
```

### 6.2 最终配置

**strongswan.conf**:
```conf
charon {
    load_modular = yes
    
    plugins {
        gmssl {
            load = yes
        }
    }
}
```

**swanctl.conf**:
```conf
connections {
    production-vpn {
        version = 2
        mobike = no
        reauth_time = 10800
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = "C=CN, O=MyOrg, CN=vpn.example.com"
        }
        
        remote {
            auth = pubkey
        }
        
        # 国密提案（优先） + 国际算法（备用）
        proposals = sm4128-sm3-sm2,aes256-sha256-modp2048
        
        children {
            tunnel {
                esp_proposals = sm4128-sm3,aes256-sha256
                local_ts = 192.168.1.0/24
                remote_ts = 0.0.0.0/0
                updown = /usr/local/libexec/ipsec/_updown
                rekey_time = 3600
            }
        }
    }
}
```

### 6.3 启动和监控

```bash
# 启动strongSwan
systemctl start strongswan

# 加载配置
swanctl --load-all

# 查看状态
swanctl --list-sas
swanctl --list-conns

# 实时日志
tail -f /var/log/syslog | grep charon
```

---

## 7. 关键参考文档

### 7.1 已有文档索引

1. **strongSwan国密算法集成详细方案.md**
   - 核心代码架构分析
   - 算法标识符定义
   - 插件系统详解

2. **国密算法映射和应用场景详解.md**
   - GmSSL API使用方法
   - 算法使用场景分析
   - 具体代码示例

3. **算法提案详解.md**
   - IKE/ESP提案机制
   - 算法协商流程
   - 配置文件语法

4. **原始strongSwan加密算法调用流程图.md**
   - 完整的调用链路
   - 关键函数位置
   - 密钥派生过程

5. **IKE密钥vs ESP密钥详解.md**
   - 密钥层次结构
   - SKEYSEED派生
   - Child SA密钥管理

### 7.2 外部资源

- GmSSL官方文档: http://gmssl.org
- GmSSL GitHub: https://github.com/guanzhi/GmSSL
- strongSwan文档: https://docs.strongswan.org
- GM/T 0003-2012 SM2规范
- GM/T 0004-2012 SM3规范
- GM/T 0002-2012 SM4规范

---

## 8. 风险和应对措施

### 8.1 技术风险

| 风险 | 影响 | 应对措施 |
|------|------|----------|
| GmSSL API不稳定 | 高 | 使用稳定版本(v3.1.1)，锁定版本号 |
| SM2密钥交换复杂 | 中 | 参考OpenSSL的ECDH实现，分阶段实现 |
| 性能不达标 | 中 | 使用GmSSL的汇编优化，启用硬件加速 |
| 互操作性问题 | 高 | 提供国际算法备用方案，渐进式迁移 |

### 8.2 进度风险

| 风险 | 应对措施 |
|------|----------|
| SM2实现复杂度超预期 | 简化第一版，仅支持基本功能 |
| 测试用例不足 | 参考strongSwan现有测试框架 |
| 文档不完善 | 边开发边记录，使用注释生成文档 |

---

## 9. 成功标准

### 9.1 功能完整性

- ✅ SM4-CBC/CTR/GCM加密正常工作
- ✅ SM3哈希和HMAC-SM3正常工作
- ✅ SM2密钥交换和签名正常工作
- ✅ IKE和ESP能够协商国密提案
- ✅ 与国际算法兼容，支持混合部署

### 9.2 性能指标

- SM4加密吞吐量 ≥ 500 Mbps (千兆网络)
- IKE协商时间 < 200ms
- ESP加密开销 < 10% CPU

### 9.3 稳定性

- 连续运行7天无崩溃
- 重密钥操作正常
- 异常情况能够优雅降级

---

## 10. 总结

本计划采用**插件化架构 + GmSSL库**的方案，具有以下优势：

1. **开发效率高**：利用成熟的GmSSL库，节省70%开发时间
2. **风险可控**：插件化设计，不影响现有功能
3. **易于维护**：清晰的代码结构，便于后续升级
4. **合规性强**：使用国密局认证的GmSSL库

预计**7-9周**完成开发和测试，能够满足国密算法应用需求。
