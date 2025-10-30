# strongSwan国密算法集成详细方案

## 目录
- [1. strongSwan代码架构深度解析](#1-strongswan代码架构深度解析)
- [2. 国密算法集成详细方案](#2-国密算法集成详细方案)
- [3. 部署和优化建议](#3-部署和优化建议)

## 1. strongSwan代码架构深度解析

### 1.1 整体架构概览

strongSwan采用典型的**分层模块化架构**，主要由以下几个核心层次组成：

```
应用层 (Applications)
├── swanctl (现代配置工具)
├── ipsec (传统脚本)
├── pki (证书管理)
└── charon (IKE守护进程)

协议层 (Protocol Layer) 
├── libcharon (IKE/IPsec协议实现)
├── libtls (TLS协议支持)
└── libradius (RADIUS认证)

核心库层 (Core Library)
└── libstrongswan (基础设施)
    ├── crypto (加密算法框架)
    ├── plugins (插件系统)
    ├── credentials (证书/密钥管理)
    ├── networking (网络通信)
    └── utils (工具库)

系统层 (System Layer)
├── 内核接口 (Kernel Interface)
└── 操作系统API
```

### 1.2 libstrongswan核心架构详解

#### 1.2.1 library.h - 全局库实例

```c
// 核心库实例，包含所有子系统的引用
struct library_t {
    crypto_factory_t *crypto;        // 加密算法工厂
    credential_factory_t *creds;     // 证书工厂  
    plugin_loader_t *plugins;        // 插件加载器
    settings_t *settings;            // 配置管理
    // ... 其他子系统
};
extern library_t *lib;  // 全局库实例
```

#### 1.2.2 插件系统架构

**插件加载机制**：

1. **plugin_loader.h** - 插件加载器
   - 负责动态加载.so插件文件
   - 解析插件依赖关系
   - 按优先级排序加载

2. **plugin_feature.h** - 功能特性系统
   ```c
   // 插件功能声明宏
   PLUGIN_REGISTER(CRYPTER, openssl_crypter_create),
       PLUGIN_PROVIDE(CRYPTER, ENCR_AES_CBC, 16),
       PLUGIN_PROVIDE(CRYPTER, ENCR_AES_CBC, 24),
       PLUGIN_PROVIDE(CRYPTER, ENCR_AES_CBC, 32),
   ```

3. **plugin.h** - 插件接口定义
   ```c
   struct plugin_t {
       char* (*get_name)(plugin_t *this);
       int (*get_features)(plugin_t *this, plugin_feature_t *features[]);
       void (*destroy)(plugin_t *this);
   };
   ```

#### 1.2.3 加密算法框架

**crypto_factory.c** - 加密工厂实现：
```c
struct private_crypto_factory_t {
    linked_list_t *crypters;     // 对称加密算法列表
    linked_list_t *aeads;        // AEAD算法列表  
    linked_list_t *signers;      // 签名算法列表
    linked_list_t *hashers;      // 哈希算法列表
    linked_list_t *prfs;         // PRF算法列表
    // ...
    rwlock_t *lock;              // 读写锁保护
};
```

**算法注册流程**：
1. 插件通过 `PLUGIN_REGISTER` 注册构造函数
2. crypto_factory 将构造函数存储在对应链表中
3. 运行时通过工厂方法创建算法实例

### 1.3 libcharon协议层架构

#### 1.3.1 IKE协议实现
- **sa/ikev2/** - IKEv2协议状态机
- **sa/ikev1/** - IKEv1协议支持
- **encoding/** - 消息编解码
- **config/** - 配置管理

#### 1.3.2 IPsec数据平面
- **kernel/** - 内核接口抽象
- **plugins/kernel-netlink/** - Linux netlink接口

### 1.4 配置系统架构

#### 1.4.1 现代配置接口 (swanctl)
- **src/swanctl/** - 命令行工具
- **src/libcharon/plugins/vici/** - VICI协议接口
- **swanctl.conf** - 配置文件格式

#### 1.4.2 传统接口 (ipsec)
- **src/starter/** - 配置解析器
- **src/stroke/** - stroke协议接口

## 2. 国密算法集成详细方案

### 第一阶段：基础设施准备（3-4周）

#### 2.1 算法标识符扩展

**修改 `src/libstrongswan/crypto/crypters/crypter.h`**：
```c
enum encryption_algorithm_t {
    // 现有算法...
    ENCR_CHACHA20_POLY1305 = 28,
    
    // 新增国密算法 (使用私有编号范围)
    ENCR_SM4_CBC = 1031,
    ENCR_SM4_ECB = 1032, 
    ENCR_SM4_CTR = 1033,
    ENCR_SM4_GCM = 1034,
    ENCR_SM4_CCM = 1035,
};

// SM4分组大小定义
#define SM4_BLOCK_SIZE 16
```

**修改 `src/libstrongswan/crypto/hashers/hasher.h`**：
```c
enum hash_algorithm_t {
    // 现有算法...
    HASH_SHA3_512 = 1031,
    
    // 新增SM3
    HASH_SM3 = 1032,
};

#define HASH_SIZE_SM3 32  // SM3输出256位
```

**修改 `src/libstrongswan/credentials/keys/public_key.h`**：
```c
enum key_type_t {
    // 现有类型...
    KEY_ED448 = 5,
    
    // 新增SM2
    KEY_SM2 = 6,
};

enum signature_scheme_t {
    // 现有方案...
    SIGN_ED448,
    
    // 新增SM2签名
    SIGN_SM2_WITH_SM3,
    SIGN_SM2_WITH_NULL,  // 用于预计算摘要
};
```

#### 2.2 创建GM插件框架

**目录结构**：
```
src/libstrongswan/plugins/gmsm/
├── Makefile.am
├── gmsm_plugin.h
├── gmsm_plugin.c
├── gmsm_crypter.h        # SM4实现
├── gmsm_crypter.c
├── gmsm_hasher.h         # SM3实现  
├── gmsm_hasher.c
├── gmsm_signer.h         # HMAC-SM3实现
├── gmsm_signer.c
├── gmsm_public_key.h     # SM2公钥
├── gmsm_public_key.c
├── gmsm_private_key.h    # SM2私钥
├── gmsm_private_key.c
├── gmsm_util.h           # 通用工具
├── gmsm_util.c
└── tests/                # 测试代码
    ├── gmsm_test_vectors.h
    └── gmsm_tests.c
```

**gmsm_plugin.c 框架**：
```c
#include "gmsm_plugin.h"
#include "gmsm_crypter.h"
#include "gmsm_hasher.h"
#include "gmsm_signer.h"
#include "gmsm_public_key.h"
#include "gmsm_private_key.h"

typedef struct private_gmsm_plugin_t private_gmsm_plugin_t;

struct private_gmsm_plugin_t {
    gmsm_plugin_t public;
};

METHOD(plugin_t, get_name, char*,
    private_gmsm_plugin_t *this)
{
    return "gmsm";
}

METHOD(plugin_t, get_features, int,
    private_gmsm_plugin_t *this, plugin_feature_t *features[])
{
    static plugin_feature_t f[] = {
        // SM4对称加密
        PLUGIN_REGISTER(CRYPTER, gmsm_crypter_create),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CBC, 16),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_ECB, 16),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CTR, 16),
            PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_GCM, 16),
            
        // SM3哈希
        PLUGIN_REGISTER(HASHER, gmsm_hasher_create),
            PLUGIN_PROVIDE(HASHER, HASH_SM3),
            
        // HMAC-SM3
        PLUGIN_REGISTER(SIGNER, gmsm_signer_create),
            PLUGIN_PROVIDE(SIGNER, AUTH_HMAC_SM3_256),
            
        // SM2密钥支持  
        PLUGIN_REGISTER(PUBKEY, gmsm_public_key_load, TRUE),
            PLUGIN_PROVIDE(PUBKEY, KEY_SM2),
        PLUGIN_REGISTER(PRIVKEY, gmsm_private_key_load, TRUE),
            PLUGIN_PROVIDE(PRIVKEY, KEY_SM2),
        PLUGIN_REGISTER(PRIVKEY_GEN, gmsm_private_key_gen, FALSE),
            PLUGIN_PROVIDE(PRIVKEY_GEN, KEY_SM2),
            
        // SM2签名
        PLUGIN_PROVIDE(PRIVKEY_SIGN, SIGN_SM2_WITH_SM3),
        PLUGIN_PROVIDE(PUBKEY_VERIFY, SIGN_SM2_WITH_SM3),
    };
    
    *features = f;
    return countof(f);
}

// 插件创建函数
plugin_t *gmsm_plugin_create()
{
    private_gmsm_plugin_t *this;
    
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

#### 2.3 构建系统集成

**修改 `configure.ac`**：
```bash
# 在适当位置添加
ARG_ENABL_SET([gmsm], [enable GM/T SM2/SM3/SM4 crypto plugin.])

# 在输出部分添加
src/libstrongswan/plugins/gmsm/Makefile
```

**创建 `src/libstrongswan/plugins/gmsm/Makefile.am`**：
```makefile
AM_CPPFLAGS = \
    -I$(top_srcdir)/src/libstrongswan

AM_CFLAGS = \
    $(PLUGIN_CFLAGS)

if MONOLITHIC
noinst_LTLIBRARIES = libstrongswan-gmsm.la
else
plugin_LTLIBRARIES = libstrongswan-gmsm.la
endif

libstrongswan_gmsm_la_SOURCES = \
    gmsm_plugin.h gmsm_plugin.c \
    gmsm_crypter.h gmsm_crypter.c \
    gmsm_hasher.h gmsm_hasher.c \
    gmsm_signer.h gmsm_signer.c \
    gmsm_public_key.h gmsm_public_key.c \
    gmsm_private_key.h gmsm_private_key.c \
    gmsm_util.h gmsm_util.c

libstrongswan_gmsm_la_LDFLAGS = -module -avoid-version
```

### 第二阶段：SM4对称加密实现（2-3周）

#### 2.1 SM4核心算法实现

**gmsm_crypter.h**：
```c
#ifndef GMSM_CRYPTER_H_
#define GMSM_CRYPTER_H_

#include <crypto/crypters/crypter.h>

typedef struct gmsm_crypter_t gmsm_crypter_t;

/**
 * SM4加密器实现
 */
struct gmsm_crypter_t {
    /**
     * crypter_t接口
     */
    crypter_t crypter;
};

/**
 * 创建SM4加密器
 *
 * @param algo          加密算法类型
 * @param key_size      密钥长度(字节)
 * @return              crypter_t实例，失败返回NULL
 */
crypter_t *gmsm_crypter_create(encryption_algorithm_t algo, size_t key_size);

#endif /** GMSM_CRYPTER_H_ @}*/
```

**gmsm_crypter.c 主要结构**：
```c
#include "gmsm_crypter.h"
#include "gmsm_util.h"

typedef struct private_gmsm_crypter_t private_gmsm_crypter_t;

struct private_gmsm_crypter_t {
    gmsm_crypter_t public;
    
    encryption_algorithm_t algorithm;
    size_t key_size;
    
    // SM4密钥调度结果
    uint32_t round_keys[32];
    bool keys_set;
};

// SM4 S盒
static const uint8_t SM4_SBOX[256] = {
    0xd6, 0x90, 0xe9, 0xfe, 0xcc, 0xe1, 0x3d, 0xb7,
    // ... 完整S盒数据
};

// SM4轮函数
static uint32_t sm4_round_function(uint32_t x)
{
    uint8_t *bytes = (uint8_t*)&x;
    uint32_t result = 0;
    
    // S盒变换
    for (int i = 0; i < 4; i++) {
        ((uint8_t*)&result)[i] = SM4_SBOX[bytes[i]];
    }
    
    // 线性变换L
    return result ^ ROL32(result, 2) ^ ROL32(result, 10) ^ 
           ROL32(result, 18) ^ ROL32(result, 24);
}

// 密钥扩展
static void sm4_key_schedule(const uint8_t *key, uint32_t *round_keys)
{
    uint32_t FK[4] = {0xa3b1bac6, 0x56aa3350, 0x677d9197, 0xb27022dc};
    uint32_t CK[32] = {/* 固定参数CK */};
    
    uint32_t K[36];
    
    // 初始化
    for (int i = 0; i < 4; i++) {
        K[i] = GET_UINT32_BE(key, i*4) ^ FK[i];
    }
    
    // 生成轮密钥
    for (int i = 0; i < 32; i++) {
        uint32_t temp = K[i+1] ^ K[i+2] ^ K[i+3] ^ CK[i];
        K[i+4] = K[i] ^ (sm4_t_function(temp));
        round_keys[i] = K[i+4];
    }
}

// SM4加密单个分组
static void sm4_encrypt_block(const uint32_t *round_keys, 
                             const uint8_t *input, uint8_t *output)
{
    uint32_t X[36];
    
    // 加载输入
    for (int i = 0; i < 4; i++) {
        X[i] = GET_UINT32_BE(input, i*4);
    }
    
    // 32轮迭代
    for (int i = 0; i < 32; i++) {
        X[i+4] = X[i] ^ sm4_round_function(X[i+1] ^ X[i+2] ^ X[i+3] ^ round_keys[i]);
    }
    
    // 反序输出
    for (int i = 0; i < 4; i++) {
        PUT_UINT32_BE(X[35-i], output, i*4);
    }
}

METHOD(crypter_t, set_key, bool,
    private_gmsm_crypter_t *this, chunk_t key)
{
    if (key.len != this->key_size) {
        return FALSE;
    }
    
    sm4_key_schedule(key.ptr, this->round_keys);
    this->keys_set = TRUE;
    return TRUE;
}

METHOD(crypter_t, encrypt, bool,
    private_gmsm_crypter_t *this, chunk_t data, chunk_t iv, chunk_t *encrypted)
{
    if (!this->keys_set) {
        return FALSE;
    }
    
    switch (this->algorithm) {
        case ENCR_SM4_ECB:
            return sm4_ecb_encrypt(this, data, encrypted);
        case ENCR_SM4_CBC:
            return sm4_cbc_encrypt(this, data, iv, encrypted);
        case ENCR_SM4_CTR:
            return sm4_ctr_encrypt(this, data, iv, encrypted);
        case ENCR_SM4_GCM:
            return sm4_gcm_encrypt(this, data, iv, encrypted);
        default:
            return FALSE;
    }
}

// ... 其他方法实现
```

#### 2.2 多种工作模式实现

**ECB模式**：
```c
static bool sm4_ecb_encrypt(private_gmsm_crypter_t *this, 
                           chunk_t data, chunk_t *encrypted)
{
    if (data.len % SM4_BLOCK_SIZE != 0) {
        return FALSE;
    }
    
    *encrypted = chunk_alloc(data.len);
    
    for (size_t i = 0; i < data.len; i += SM4_BLOCK_SIZE) {
        sm4_encrypt_block(this->round_keys, 
                         data.ptr + i, 
                         encrypted->ptr + i);
    }
    return TRUE;
}
```

**CBC模式**：
```c
static bool sm4_cbc_encrypt(private_gmsm_crypter_t *this,
                           chunk_t data, chunk_t iv, chunk_t *encrypted)
{
    uint8_t block[SM4_BLOCK_SIZE];
    uint8_t chain[SM4_BLOCK_SIZE];
    
    if (iv.len != SM4_BLOCK_SIZE || data.len % SM4_BLOCK_SIZE != 0) {
        return FALSE;
    }
    
    *encrypted = chunk_alloc(data.len);
    memcpy(chain, iv.ptr, SM4_BLOCK_SIZE);
    
    for (size_t i = 0; i < data.len; i += SM4_BLOCK_SIZE) {
        // XOR with chain
        for (int j = 0; j < SM4_BLOCK_SIZE; j++) {
            block[j] = data.ptr[i + j] ^ chain[j];
        }
        
        sm4_encrypt_block(this->round_keys, block, encrypted->ptr + i);
        memcpy(chain, encrypted->ptr + i, SM4_BLOCK_SIZE);
    }
    return TRUE;
}
```

### 第三阶段：SM3哈希算法实现（1-2周）

#### 3.1 SM3核心实现

**gmsm_hasher.c**：
```c
#include "gmsm_hasher.h"

#define SM3_DIGEST_SIZE 32
#define SM3_BLOCK_SIZE 64

typedef struct private_gmsm_hasher_t private_gmsm_hasher_t;

struct private_gmsm_hasher_t {
    gmsm_hasher_t public;
    
    // SM3状态
    uint32_t state[8];
    uint64_t count;
    uint8_t buffer[SM3_BLOCK_SIZE];
    size_t buffer_len;
};

// SM3初始值
static const uint32_t SM3_IV[8] = {
    0x7380166f, 0x4914b2b9, 0x172442d7, 0xda8a0600,
    0xa96f30bc, 0x163138aa, 0xe38dee4d, 0xb0fb0e4e
};

// SM3压缩函数
static void sm3_compress(uint32_t *state, const uint8_t *block)
{
    uint32_t W[68], W1[64];
    uint32_t A, B, C, D, E, F, G, H;
    uint32_t SS1, SS2, TT1, TT2, T;
    
    // 消息扩展
    for (int j = 0; j < 16; j++) {
        W[j] = GET_UINT32_BE(block, j * 4);
    }
    
    for (int j = 16; j < 68; j++) {
        uint32_t temp = W[j-16] ^ W[j-9] ^ ROL32(W[j-3], 15);
        W[j] = P1(temp) ^ ROL32(W[j-13], 7) ^ W[j-6];
    }
    
    for (int j = 0; j < 64; j++) {
        W1[j] = W[j] ^ W[j+4];
    }
    
    // 加载状态
    A = state[0]; B = state[1]; C = state[2]; D = state[3];
    E = state[4]; F = state[5]; G = state[6]; H = state[7];
    
    // 64轮压缩
    for (int j = 0; j < 64; j++) {
        T = (j < 16) ? 0x79cc4519 : 0x7a879d8a;
        SS1 = ROL32((ROL32(A, 12) + E + ROL32(T, j % 32)), 7);
        SS2 = SS1 ^ ROL32(A, 12);
        
        TT1 = FF(A, B, C, j) + D + SS2 + W1[j];
        TT2 = GG(E, F, G, j) + H + SS1 + W[j];
        
        D = C;
        C = ROL32(B, 9);
        B = A;
        A = TT1;
        H = G;
        G = ROL32(F, 19);
        F = E;
        E = P0(TT2);
        
        A &= 0xffffffff; B &= 0xffffffff; C &= 0xffffffff; D &= 0xffffffff;
        E &= 0xffffffff; F &= 0xffffffff; G &= 0xffffffff; H &= 0xffffffff;
    }
    
    // 更新状态
    state[0] ^= A; state[1] ^= B; state[2] ^= C; state[3] ^= D;
    state[4] ^= E; state[5] ^= F; state[6] ^= G; state[7] ^= H;
}

METHOD(hasher_t, get_hash, bool,
    private_gmsm_hasher_t *this, chunk_t data, uint8_t *hash)
{
    if (data.len > 0) {
        // 处理输入数据
        sm3_update(this, data);
    }
    
    if (hash) {
        // 输出最终哈希值
        return sm3_final(this, hash);
    }
    return TRUE;
}

// ... 其他方法实现
```

### 第四阶段：SM2公钥算法实现（3-4周）

#### 4.1 SM2椭圆曲线参数

**gmsm_util.h**：
```c
// SM2推荐曲线参数
typedef struct sm2_curve_params_t {
    chunk_t p;      // 素数模
    chunk_t a;      // 曲线参数a  
    chunk_t b;      // 曲线参数b
    chunk_t gx;     // 基点G的x坐标
    chunk_t gy;     // 基点G的y坐标
    chunk_t n;      // 基点G的阶
} sm2_curve_params_t;

extern const sm2_curve_params_t SM2_CURVE_PARAMS;
```

#### 4.2 SM2私钥实现

**gmsm_private_key.c**：
```c
typedef struct private_gmsm_private_key_t private_gmsm_private_key_t;

struct private_gmsm_private_key_t {
    gmsm_private_key_t public;
    
    // SM2私钥
    chunk_t d;              // 私钥值
    chunk_t public_point;   // 对应公钥点
    
    // 曲线参数缓存
    ec_point_t *G;          // 基点
    ec_field_t *field;      // 有限域
};

METHOD(private_key_t, sign, bool,
    private_gmsm_private_key_t *this, signature_scheme_t scheme,
    void *params, chunk_t data, chunk_t *signature)
{
    switch (scheme) {
        case SIGN_SM2_WITH_SM3:
            return sm2_sign_with_sm3(this, data, signature);
        case SIGN_SM2_WITH_NULL:
            return sm2_sign_hash(this, data, signature);
        default:
            return FALSE;
    }
}

// SM2签名算法实现
static bool sm2_sign_with_sm3(private_gmsm_private_key_t *this,
                              chunk_t data, chunk_t *signature)
{
    hasher_t *hasher;
    chunk_t hash, za, m_tilde;
    bool success = FALSE;
    
    // 1. 计算ZA = SM3(ENTLA || IDA || a || b || xG || yG || xA || yA)
    za = sm2_compute_za(this, DEFAULT_ID);
    
    // 2. 计算M' = ZA || M
    m_tilde = chunk_cat("cc", za, data);
    
    // 3. 计算哈希值e = SM3(M')
    hasher = lib->crypto->create_hasher(lib->crypto, HASH_SM3);
    if (!hasher || !hasher->allocate_hash(hasher, m_tilde, &hash)) {
        goto cleanup;
    }
    
    // 4. SM2签名算法
    success = sm2_sign_hash(this, hash, signature);
    
cleanup:
    DESTROY_IF(hasher);
    chunk_free(&za);
    chunk_free(&m_tilde); 
    chunk_free(&hash);
    return success;
}

static bool sm2_sign_hash(private_gmsm_private_key_t *this,
                         chunk_t hash, chunk_t *signature)
{
    rng_t *rng;
    chunk_t k, r, s, e;
    bignum_t *bn_k, *bn_r, *bn_s, *bn_e, *bn_d, *bn_n;
    ec_point_t *point;
    bool success = FALSE;
    
    // 准备大数
    bn_e = bignum_create_from_chunk(hash);
    bn_d = bignum_create_from_chunk(this->d);
    bn_n = bignum_create_from_chunk(SM2_CURVE_PARAMS.n);
    
    rng = lib->crypto->create_rng(lib->crypto, RNG_STRONG);
    if (!rng) {
        goto cleanup;
    }
    
    do {
        // 1. 生成随机数k ∈ [1, n-1]
        if (!rng->allocate_bytes(rng, 32, &k)) {
            goto cleanup;
        }
        bn_k = bignum_create_from_chunk(k);
        
        // 2. 计算椭圆曲线点(x1, y1) = [k]G
        point = ec_point_multiply(this->G, bn_k);
        if (!point) {
            goto retry;
        }
        
        // 3. 计算r = (e + x1) mod n
        chunk_t x1 = ec_point_get_x(point);
        bn_r = bignum_add(bn_e, bignum_create_from_chunk(x1));
        bn_r = bignum_mod(bn_r, bn_n);
        
        // 检查r是否为0或r+k是否为n
        if (bignum_is_zero(bn_r)) {
            goto retry;
        }
        
        // 4. 计算s = (1 + dA)^(-1) * (k - r * dA) mod n
        bignum_t *bn_one = bignum_create_from_word(1);
        bignum_t *bn_inv = bignum_mod_inverse(bignum_add(bn_one, bn_d), bn_n);
        bignum_t *bn_temp = bignum_sub(bn_k, bignum_mul_mod(bn_r, bn_d, bn_n));
        bn_s = bignum_mul_mod(bn_inv, bn_temp, bn_n);
        
        // 检查s是否为0
        if (bignum_is_zero(bn_s)) {
            goto retry;
        }
        
        success = TRUE;
        break;
        
retry:
        // 清理并重试
        chunk_clear(&k);
        DESTROY_IF(point);
        // ... 清理其他临时变量
        
    } while (!success);
    
    if (success) {
        // 编码签名 (r, s)
        chunk_t r_chunk = bignum_to_chunk(bn_r);
        chunk_t s_chunk = bignum_to_chunk(bn_s);
        *signature = asn1_wrap(ASN1_SEQUENCE, "mm", 
                              asn1_integer("c", r_chunk),
                              asn1_integer("c", s_chunk));
    }
    
cleanup:
    // 清理资源...
    return success;
}
```

### 第五阶段：协议层集成（2-3周）

#### 5.1 算法提案支持

**修改 `src/libstrongswan/crypto/proposal/proposal_keywords_static.txt`**：
```
# 新增SM算法关键字
sm4,              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4-128,          ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4cbc,           ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4cbc128,        ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4ecb,           ENCRYPTION_ALGORITHM, ENCR_SM4_ECB,            128
sm4ctr,           ENCRYPTION_ALGORITHM, ENCR_SM4_CTR,            128
sm4gcm,           ENCRYPTION_ALGORITHM, ENCR_SM4_GCM,            128

sm3,              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_256,         0
hmac-sm3,         INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_256,         0
sm3-256,          INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_256,         0
```

#### 5.2 默认算法提案

**修改 `src/libstrongswan/crypto/proposal/proposal.c`**：
```c
// 在add_supported_ike()函数中添加SM算法支持
static bool add_supported_ike(private_proposal_t *this, bool aead)
{
    enumerator_t *enumerator;
    encryption_algorithm_t encryption;
    integrity_algorithm_t integrity;
    
    if (aead) {
        enumerator = lib->crypto->create_aead_enumerator(lib->crypto);
        while (enumerator->enumerate(enumerator, &encryption, &plugin_name)) {
            switch (encryption) {
                // 现有算法...
                case ENCR_SM4_GCM:
                    add_algorithm(this, ENCRYPTION_ALGORITHM, encryption, 128);
                    break;
                // ...
            }
        }
    } else {
        enumerator = lib->crypto->create_crypter_enumerator(lib->crypto);
        while (enumerator->enumerate(enumerator, &encryption, &plugin_name)) {
            switch (encryption) {
                // 现有算法...
                case ENCR_SM4_CBC:
                case ENCR_SM4_CTR:
                    add_algorithm(this, ENCRYPTION_ALGORITHM, encryption, 128);
                    break;
                // ...
            }
        }
        
        // 添加完整性算法
        enumerator = lib->crypto->create_signer_enumerator(lib->crypto);
        while (enumerator->enumerate(enumerator, &integrity, &plugin_name)) {
            switch (integrity) {
                // 现有算法...
                case AUTH_HMAC_SM3_256:
                    add_algorithm(this, INTEGRITY_ALGORITHM, integrity, 0);
                    break;
                // ...
            }
        }
    }
    
    return TRUE;
}
```

### 第六阶段：配置和测试（2-3周）

#### 6.1 配置文件支持

**修改swanctl配置**：
```yaml
# swanctl.conf示例
connections {
    gmsm-connection {
        version = 2
        proposals = sm4-sm3-sm2dh
        local_addrs = 192.168.1.1
        remote_addrs = 192.168.1.2
        
        local {
            auth = pubkey
            certs = local-sm2.pem
            id = "CN=Local-GM"
        }
        
        remote {
            auth = pubkey 
            id = "CN=Remote-GM"
        }
        
        children {
            gmsm-child {
                esp_proposals = sm4-sm3
                local_ts = 10.0.1.0/24
                remote_ts = 10.0.2.0/24
            }
        }
    }
}
```

#### 6.2 测试向量验证

**gmsm_tests.c**：
```c
#include "gmsm_test_vectors.h"

// SM4测试向量
static struct {
    chunk_t key;
    chunk_t plaintext;
    chunk_t ciphertext;
} sm4_test_vectors[] = {
    // GM/T 0002-2012标准测试向量
    {
        .key = chunk_from_chars(
            0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
            0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
        ),
        .plaintext = chunk_from_chars(
            0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
            0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
        ),
        .ciphertext = chunk_from_chars(
            0x68, 0x1e, 0xdf, 0x34, 0xd2, 0x06, 0x96, 0x5e,
            0x86, 0xb3, 0xe9, 0x4f, 0x53, 0x6e, 0x42, 0x46
        ),
    },
    // 更多测试向量...
};

START_TEST(test_sm4_ecb)
{
    crypter_t *crypter;
    chunk_t encrypted, decrypted;
    int i;
    
    crypter = lib->crypto->create_crypter(lib->crypto, ENCR_SM4_ECB, 16);
    ck_assert(crypter != NULL);
    
    for (i = 0; i < countof(sm4_test_vectors); i++) {
        // 测试加密
        ck_assert(crypter->set_key(crypter, sm4_test_vectors[i].key));
        ck_assert(crypter->encrypt(crypter, sm4_test_vectors[i].plaintext, 
                                  chunk_empty, &encrypted));
        ck_assert(chunk_equals(encrypted, sm4_test_vectors[i].ciphertext));
        
        // 测试解密
        ck_assert(crypter->decrypt(crypter, encrypted, chunk_empty, &decrypted));
        ck_assert(chunk_equals(decrypted, sm4_test_vectors[i].plaintext));
        
        chunk_free(&encrypted);
        chunk_free(&decrypted);
    }
    
    crypter->destroy(crypter);
}
END_TEST
```

## 3. 部署和优化建议

### 3.1 性能优化策略

#### 3.1.1 硬件加速支持
- 利用Intel AES-NI指令集加速SM4（如果CPU支持）
- 考虑使用汇编优化关键循环
- 支持多线程并行处理

#### 3.1.2 内存管理优化
- 使用内存池减少频繁分配
- 密钥材料安全清零
- 缓存椭圆曲线计算结果

### 3.2 安全考虑

#### 3.2.1 侧信道攻击防护
- 常数时间算法实现
- 密钥材料存储保护
- 随机数质量保证

#### 3.2.2 标准合规性
- 严格按照GM/T标准实现
- 通过国密局认证测试
- 定期安全审计

### 3.3 互操作性测试

#### 3.3.1 与其他国密设备测试
- 不同厂商设备互通
- 多种算法组合测试
- 边界条件处理

#### 3.3.2 向后兼容性
- 支持国际算法回退
- 渐进式部署方案
- 配置灵活性保证

## 4. 项目时间线和里程碑

### 阶段概览
| 阶段 | 时间 | 主要交付物 | 里程碑 |
|------|------|-----------|--------|
| 第一阶段 | 3-4周 | 基础框架和枚举定义 | 插件可加载，框架搭建完成 |
| 第二阶段 | 2-3周 | SM4算法实现 | SM4各模式通过标准测试向量 |
| 第三阶段 | 1-2周 | SM3哈希算法 | SM3通过标准测试向量 |
| 第四阶段 | 3-4周 | SM2公钥算法 | SM2签名验证功能完成 |
| 第五阶段 | 2-3周 | 协议层集成 | IKE/IPsec可使用国密算法 |
| 第六阶段 | 2-3周 | 测试和优化 | 完整功能测试通过 |

### 总工期：12-16周

### 关键风险和缓解措施

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 算法实现错误 | 高 | 严格按标准实现，使用官方测试向量验证 |
| 性能不达标 | 中 | 早期性能测试，必要时使用硬件加速 |
| 互操作性问题 | 中 | 与主流国密设备进行互通测试 |
| 安全漏洞 | 高 | 代码安全审计，侧信道攻击防护 |

## 5. 结论

本方案提供了一个完整的strongSwan国密算法集成路径，涵盖了从底层算法实现到上层协议集成的全部环节。通过模块化的插件架构，可以在不影响现有功能的情况下，逐步添加国密算法支持。

该方案的主要优势：
1. **完全兼容**：保持与现有strongSwan架构的完全兼容
2. **标准合规**：严格按照GM/T国标实现
3. **模块化设计**：便于维护和升级
4. **渐进部署**：支持国密与国际算法并存
5. **性能优化**：考虑了硬件加速和优化方案

建议分阶段实施，确保每个阶段都有可验证的交付物，降低项目风险，提高成功率。
