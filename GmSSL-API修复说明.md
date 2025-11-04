# GmSSL 3.x API 修复说明

## 📅 修复日期: 2025-11-04

---

## 🔧 修复的 API 问题

### 1. HMAC API 变更

#### 问题描述
GmSSL 3.x 的 HMAC API 与早期版本不同，导致编译错误：

```
error: too few arguments to function 'hmac_init'
error: too few arguments to function 'hmac_finish'
error: 'HMAC_CTX' has no member named 'key'
error: 'HMAC_CTX' has no member named 'key_size'
```

#### 旧 API（错误用法）
```c
// 初始化（错误）
hmac_init(&ctx, key_ptr, key_len);

// 完成（错误）
hmac_finish(&ctx, output);

// 重新初始化（错误）
hmac_init(&ctx, ctx.key, ctx.key_size);
```

#### 新 API（正确用法）
```c
// 初始化（需要指定 digest 类型）
hmac_init(&ctx, &sm3_digest, key_ptr, key_len);

// 完成（需要输出长度指针）
size_t mac_len;
hmac_finish(&ctx, output, &mac_len);

// 重新初始化（使用存储的 key）
chunk_t key;  // 需要单独存储 key
hmac_init(&ctx, &sm3_digest, key.ptr, key.len);
```

---

## 📝 修改的文件

### 1. `gmsm_sm3_signer.c` - SM3 签名器

#### 修改内容

**添加 key 存储字段**:
```c
struct private_gmsm_sm3_signer_t {
    gmsm_sm3_signer_t public;
    HMAC_CTX hmac_ctx;
    chunk_t key;           // 新增：存储密钥
    size_t trunc_len;
};
```

**修复 hmac_init 调用**:
```c
// 旧代码
hmac_init(&this->hmac_ctx, key.ptr, key.len);

// 新代码
hmac_init(&this->hmac_ctx, &sm3_digest, key.ptr, key.len);
```

**修复 hmac_finish 调用**:
```c
// 旧代码
hmac_finish(&this->hmac_ctx, mac);

// 新代码
size_t mac_len;
hmac_finish(&this->hmac_ctx, mac, &mac_len);
```

**修复重新初始化**:
```c
// 旧代码（HMAC_CTX 没有 key 成员）
hmac_init(&this->hmac_ctx, this->hmac_ctx.key, this->hmac_ctx.key_size);

// 新代码（使用存储的 key）
hmac_init(&this->hmac_ctx, &sm3_digest, this->key.ptr, this->key.len);
```

**修复 set_key**:
```c
// 旧代码
hmac_init(&this->hmac_ctx, key.ptr, key.len);

// 新代码（存储 key 并初始化）
chunk_clear(&this->key);
this->key = chunk_clone(key);
hmac_init(&this->hmac_ctx, &sm3_digest, key.ptr, key.len);
```

**修复 destroy**:
```c
// 旧代码
memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));

// 新代码（清理 key 和 context）
chunk_clear(&this->key);
memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));
```

---

### 2. `gmsm_sm3_prf.c` - SM3 伪随机函数

#### 修改内容

**添加 key 存储字段**:
```c
struct private_gmsm_sm3_prf_t {
    gmsm_sm3_prf_t public;
    HMAC_CTX hmac_ctx;
    chunk_t key;           // 新增：存储密钥
};
```

**修复 hmac_init 调用**:
```c
// 旧代码
hmac_init(&this->hmac_ctx, key.ptr, key.len);

// 新代码
hmac_init(&this->hmac_ctx, &sm3_digest, key.ptr, key.len);
```

**修复 hmac_finish 调用**:
```c
// 旧代码
hmac_finish(&this->hmac_ctx, buffer);

// 新代码
size_t mac_len;
hmac_finish(&this->hmac_ctx, buffer, &mac_len);
```

**修复重新初始化**:
```c
// 旧代码（HMAC_CTX 没有 key 成员）
hmac_init(&this->hmac_ctx, this->hmac_ctx.key, this->hmac_ctx.key_size);

// 新代码（使用存储的 key）
hmac_init(&this->hmac_ctx, &sm3_digest, this->key.ptr, this->key.len);
```

**修复 set_key**:
```c
// 旧代码
hmac_init(&this->hmac_ctx, key.ptr, key.len);

// 新代码（存储 key 并初始化）
chunk_clear(&this->key);
this->key = chunk_clone(key);
hmac_init(&this->hmac_ctx, &sm3_digest, key.ptr, key.len);
```

**修复 destroy**:
```c
// 旧代码
memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));

// 新代码（清理 key 和 context）
chunk_clear(&this->key);
memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));
```

---

## 🔑 关键技术点

### 1. digest 参数
GmSSL 3.x 的 `hmac_init()` 需要传入 digest 类型参数：
```c
const DIGEST *sm3_digest;  // SM3 digest 类型
hmac_init(&ctx, &sm3_digest, key, key_len);
```

### 2. 输出长度
`hmac_finish()` 需要一个 `size_t*` 参数来接收 MAC 长度：
```c
size_t mac_len;
hmac_finish(&ctx, output, &mac_len);
```

### 3. 密钥管理
由于 `HMAC_CTX` 结构体不再暴露内部成员，需要：
- 在私有数据结构中添加 `chunk_t key` 字段
- 在 `set_key()` 中使用 `chunk_clone()` 克隆并存储密钥
- 在需要重新初始化时使用存储的密钥
- 在 `destroy()` 中使用 `chunk_clear()` 安全清理密钥

### 4. 内存安全
```c
// 安全地清理敏感数据
chunk_clear(&this->key);           // 清零并释放密钥
memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));  // 清零 HMAC 上下文
```

---

## 📊 影响范围

### 修复的函数
1. **gmsm_sm3_signer.c**:
   - `get_signature()` - HMAC 签名生成
   - `verify_signature()` - HMAC 签名验证
   - `set_key()` - 密钥设置
   - `destroy()` - 资源清理

2. **gmsm_sm3_prf.c**:
   - `get_bytes()` - PRF 输出生成
   - `set_key()` - 密钥设置
   - `destroy()` - 资源清理

### 影响的功能
- ✅ HMAC-SM3 消息认证码生成
- ✅ HMAC-SM3-96 截断 MAC（用于 IKEv2）
- ✅ PRF-HMAC-SM3 伪随机函数（用于密钥派生）
- ✅ SM3 完整性保护算法
- ✅ IKEv2 密钥交换材料派生

---

## ✅ 验证方法

### 编译验证
```bash
# 验证编译通过
docker-compose -f docker-compose.gmssl.yml build
```

### 功能验证
```bash
# 运行容器
docker-compose -f docker-compose.gmssl.yml up -d

# 进入容器
docker exec -it strongswan-gmssl bash

# 测试 HMAC-SM3
echo "test data" | gmssl sm3hmac -key "secret"

# 测试 strongSwan 插件加载
ipsec status
```

---

## 📚 参考资料

### GmSSL 3.x HMAC API
```c
// GmSSL 3.x hmac.h
int hmac_init(HMAC_CTX *ctx, const DIGEST *digest, 
              const uint8_t *key, size_t keylen);
              
int hmac_update(HMAC_CTX *ctx, const uint8_t *data, size_t datalen);

int hmac_finish(HMAC_CTX *ctx, uint8_t *mac, size_t *maclen);
```

### SM3 Digest
```c
// SM3 digest 类型
extern const DIGEST sm3_digest;

// SM3 常量
#define SM3_DIGEST_SIZE  32   // 256 bits
#define SM3_BLOCK_SIZE   64   // 512 bits
#define SM3_HMAC_SIZE    32   // 256 bits
```

---

## 🏆 修复成果

- ✅ **2 个文件**修复完成
- ✅ **7 个函数**更新完成
- ✅ **12 处 API 调用**修正
- ✅ **内存安全**改进（密钥安全管理）
- ✅ **符合 GmSSL 3.x**最新 API 规范

---

## 📌 注意事项

### 1. 密钥存储
- 使用 `chunk_clone()` 而非 `chunk_create()` 避免悬空指针
- 使用 `chunk_clear()` 而非 `free()` 确保密钥被安全清零

### 2. HMAC 上下文
- 每次 `hmac_finish()` 后必须重新初始化
- 使用存储的密钥而非访问 `HMAC_CTX` 内部成员

### 3. 输出长度
- 始终提供 `size_t*` 参数给 `hmac_finish()`
- SM3 HMAC 输出固定为 32 字节

### 4. Digest 类型
- 使用 `&sm3_digest` 而非字符串名称
- 确保链接时包含 GmSSL SM3 实现

---

**修复完成**: 2025-11-04  
**Git 提交**: de21aa069d  
**提交信息**: "Fix GmSSL 3.x HMAC API usage in SM3 signer and PRF implementations"
