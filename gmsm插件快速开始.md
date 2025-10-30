# gmsm 插件快速开始指南

> 🎯 目标：30 分钟内创建并测试第一个 SM3 哈希器  
> 📅 日期：2025-10-30

---

## 📋 前置条件

✅ **已完成**：
- strongSwan 5.9.6 源码
- GmSSL 3.1.1 库已安装
- 熟悉 C 语言编程

---

## 🚀 快速路线图

```
步骤 1: 创建插件目录结构         ⏱️ 5 分钟
步骤 2: 实现 SM3 哈希器           ⏱️ 15 分钟
步骤 3: 编译和测试               ⏱️ 10 分钟
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总计                            ⏱️ 30 分钟
```

---

## 步骤 1: 创建插件目录结构 (5 分钟)

### 1.1 创建目录

```bash
cd /path/to/strongswan
mkdir -p src/libstrongswan/plugins/gmsm
cd src/libstrongswan/plugins/gmsm
```

### 1.2 创建 Makefile.am

```bash
cat > Makefile.am << 'EOF'
AM_CPPFLAGS = \
    -I$(top_srcdir)/src/libstrongswan \
    -I/usr/local/include/gmssl

AM_CFLAGS = \
    $(PLUGIN_CFLAGS)

if MONOLITHIC
noinst_LTLIBRARIES = libstrongswan-gmsm.la
else
plugin_LTLIBRARIES = libstrongswan-gmsm.la
endif

libstrongswan_gmsm_la_SOURCES = \
    gmsm_plugin.h gmsm_plugin.c \
    gmsm_sm3_hasher.h gmsm_sm3_hasher.c

libstrongswan_gmsm_la_LDFLAGS = -module -avoid-version
libstrongswan_gmsm_la_LIBADD = -lgmssl
EOF
```

---

## 步骤 2: 实现 SM3 哈希器 (15 分钟)

### 2.1 添加 SM3 枚举 (核心修改)

**文件**: `src/libstrongswan/crypto/hashers/hasher.h`

在 `enum hash_algorithm_t` 中添加（第 54 行后）：

```c
enum hash_algorithm_t {
    HASH_SHA1           = 1,
    // ... 其他算法 ...
    HASH_SHA3_512       = 1031,
    HASH_SM3            = 1032      // ← 新增
};
```

在哈希大小定义中添加（第 66 行后）：

```c
#define HASH_SIZE_SHA3_512  64
#define HASH_SIZE_SM3       32      // ← 新增
```

### 2.2 创建 gmsm_sm3_hasher.h

```bash
cat > gmsm_sm3_hasher.h << 'EOF'
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM3 hasher implementation using GmSSL
 */

#ifndef GMSM_SM3_HASHER_H_
#define GMSM_SM3_HASHER_H_

#include <crypto/hashers/hasher.h>

typedef struct gmsm_sm3_hasher_t gmsm_sm3_hasher_t;

struct gmsm_sm3_hasher_t {
    hasher_t hasher;
};

/**
 * Create a SM3 hasher
 * 
 * @param algo      must be HASH_SM3
 * @return          gmsm_sm3_hasher_t, NULL if not supported
 */
gmsm_sm3_hasher_t *gmsm_sm3_hasher_create(hash_algorithm_t algo);

#endif
EOF
```

### 2.3 创建 gmsm_sm3_hasher.c

```bash
cat > gmsm_sm3_hasher.c << 'EOF'
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM3 hasher implementation using GmSSL
 */

#include "gmsm_sm3_hasher.h"
#include <gmssl/sm3.h>
#include <string.h>

typedef struct private_gmsm_sm3_hasher_t private_gmsm_sm3_hasher_t;

struct private_gmsm_sm3_hasher_t {
    gmsm_sm3_hasher_t public;
    SM3_CTX ctx;
};

METHOD(hasher_t, reset, bool,
    private_gmsm_sm3_hasher_t *this)
{
    sm3_init(&this->ctx);
    return TRUE;
}

METHOD(hasher_t, get_hash, bool,
    private_gmsm_sm3_hasher_t *this, chunk_t chunk, uint8_t *hash)
{
    sm3_update(&this->ctx, chunk.ptr, chunk.len);
    if (hash)
    {
        sm3_finish(&this->ctx, hash);
        sm3_init(&this->ctx);
    }
    return TRUE;
}

METHOD(hasher_t, allocate_hash, bool,
    private_gmsm_sm3_hasher_t *this, chunk_t chunk, chunk_t *hash)
{
    if (hash)
    {
        *hash = chunk_alloc(HASH_SIZE_SM3);
        return get_hash(this, chunk, hash->ptr);
    }
    return get_hash(this, chunk, NULL);
}

METHOD(hasher_t, get_hash_size, size_t,
    private_gmsm_sm3_hasher_t *this)
{
    return HASH_SIZE_SM3;
}

METHOD(hasher_t, destroy, void,
    private_gmsm_sm3_hasher_t *this)
{
    memwipe(&this->ctx, sizeof(SM3_CTX));
    free(this);
}

gmsm_sm3_hasher_t *gmsm_sm3_hasher_create(hash_algorithm_t algo)
{
    private_gmsm_sm3_hasher_t *this;

    if (algo != HASH_SM3)
    {
        return NULL;
    }

    INIT(this,
        .public = {
            .hasher = {
                .reset = _reset,
                .get_hash = _get_hash,
                .allocate_hash = _allocate_hash,
                .get_hash_size = _get_hash_size,
                .destroy = _destroy,
            },
        },
    );

    sm3_init(&this->ctx);

    return &this->public;
}
EOF
```

### 2.4 创建 gmsm_plugin.h

```bash
cat > gmsm_plugin.h << 'EOF'
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * GmSSL plugin for Chinese SM2/SM3/SM4 algorithms
 */

#ifndef GMSM_PLUGIN_H_
#define GMSM_PLUGIN_H_

#include <plugins/plugin.h>

typedef struct gmsm_plugin_t gmsm_plugin_t;

struct gmsm_plugin_t {
    plugin_t plugin;
};

#endif
EOF
```

### 2.5 创建 gmsm_plugin.c

```bash
cat > gmsm_plugin.c << 'EOF'
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * GmSSL plugin for Chinese SM2/SM3/SM4 algorithms
 */

#include "gmsm_plugin.h"
#include "gmsm_sm3_hasher.h"
#include <library.h>

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
        /* SM3 hasher */
        PLUGIN_REGISTER(HASHER, gmsm_sm3_hasher_create),
            PLUGIN_PROVIDE(HASHER, HASH_SM3),
    };
    *features = f;
    return countof(f);
}

METHOD(plugin_t, destroy, void,
    private_gmsm_plugin_t *this)
{
    free(this);
}

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
EOF
```

---

## 步骤 3: 编译和测试 (10 分钟)

### 3.1 修改 configure.ac

在 `configure.ac` 中添加（约 156 行，cryptographic plugins 部分）：

```bash
ARG_ENABL_SET([gmsm],           [enable Chinese SM2/SM3/SM4 crypto plugin (GmSSL).])
```

在文件末尾 `AC_OUTPUT` 前添加：

```bash
m4_include(m4/macros/add-plugin.m4)
ADD_PLUGIN([gmsm], [s charon nm cmd])
```

### 3.2 修改 src/libstrongswan/plugins/Makefile.am

添加 gmsm 子目录（约第 100 行）：

```makefile
if USE_GMSM
  SUBDIRS += gmsm
endif
```

### 3.3 重新生成构建系统

```bash
cd /path/to/strongswan
./autogen.sh
```

### 3.4 配置编译

```bash
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-gmsm \
    --with-gmssl=/usr/local \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp

make -j $(nproc)
```

### 3.5 验证插件编译成功

```bash
ls -la src/libstrongswan/plugins/gmsm/.libs/
# 应该看到: libstrongswan-gmsm.so
```

### 3.6 安装

```bash
sudo make install
```

### 3.7 测试 SM3 哈希

创建测试程序 `test_sm3.c`:

```c
#include <stdio.h>
#include <library.h>
#include <crypto/hashers/hasher.h>

int main()
{
    library_init(NULL, "test_sm3");
    plugin_loader_t *loader = lib->plugins;
    
    /* 加载 gmsm 插件 */
    if (!loader->load(loader, "gmsm"))
    {
        fprintf(stderr, "Failed to load gmsm plugin\n");
        return 1;
    }
    
    /* 创建 SM3 哈希器 */
    hasher_t *hasher = lib->crypto->create_hasher(lib->crypto, HASH_SM3);
    if (!hasher)
    {
        fprintf(stderr, "Failed to create SM3 hasher\n");
        return 1;
    }
    
    /* 测试数据: "abc" */
    chunk_t data = chunk_from_str("abc");
    chunk_t hash = chunk_empty;
    
    if (!hasher->allocate_hash(hasher, data, &hash))
    {
        fprintf(stderr, "Hashing failed\n");
        return 1;
    }
    
    /* 输出结果 */
    printf("SM3(\"abc\") = ");
    for (int i = 0; i < hash.len; i++)
    {
        printf("%02x", hash.ptr[i]);
    }
    printf("\n");
    
    /* 预期结果: 66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0 */
    
    chunk_free(&hash);
    hasher->destroy(hasher);
    library_deinit();
    
    return 0;
}
```

编译测试：

```bash
gcc test_sm3.c -o test_sm3 \
    -I/usr/local/strongswan/include \
    -L/usr/local/strongswan/lib \
    -lstrongswan \
    -Wl,-rpath,/usr/local/strongswan/lib

./test_sm3
```

预期输出：

```
SM3("abc") = 66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0
```

---

## ✅ 完成检查清单

- [ ] 插件目录结构创建成功
- [ ] SM3 枚举添加到 hasher.h
- [ ] gmsm_sm3_hasher.c 编译无错误
- [ ] gmsm_plugin.c 注册成功
- [ ] configure.ac 修改正确
- [ ] Makefile.am 修改正确
- [ ] libstrongswan-gmsm.so 编译成功
- [ ] test_sm3 输出正确的哈希值

---

## 🎉 成功！下一步

现在您已经成功创建了第一个 SM3 哈希器！接下来可以：

1. **添加 SM4 加密器** - 参考 `国密插件开发指南.md` 阶段 3
2. **添加 SM2 非对称加密** - 参考 `国密插件开发指南.md` 阶段 4
3. **集成到 VPN 配置** - 修改 proposal.c 支持 sm3 算法名称

---

## 📚 参考资料

- **详细开发指南**: [国密插件开发指南.md](国密插件开发指南.md)
- **GmSSL API**: https://github.com/guanzhi/GmSSL/tree/master/docs
- **strongSwan 插件开发**: https://docs.strongswan.org/docs/5.9/devs/pluginArchitecture.html

---

**文档版本**: 1.0  
**创建日期**: 2025-10-30  
**预计时间**: 30 分钟  
**难度**: ⭐⭐☆☆☆
