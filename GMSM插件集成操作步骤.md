# StrongSwan 国密插件集成完整操作步骤

**项目**: strongswan-gmssl  
**GitHub**: https://github.com/HankyZhang/strongswan-gmssl  
**日期**: 2025年10月30日

---

## 📋 目录

1. [阶段一:枚举定义集成](#阶段一枚举定义集成) ✅ 已完成
2. [阶段二:gmsm 插件集成](#阶段二gmsm-插件集成) ⏳ 进行中
3. [阶段三:测试验证](#阶段三测试验证) 📅 待开始

---

## ✅ 阶段一:枚举定义集成 (已完成)

### 1.1 修改核心头文件

#### 文件 1: `src/libstrongswan/credentials/keys/public_key.h`

**添加密钥类型**:
```c
enum key_type_t {
    KEY_ANY = 0,
    KEY_RSA = 1,
    KEY_ECDSA = 2,
    KEY_DSA = 3,
    KEY_ED25519 = 4,
    KEY_ED448 = 5,
    KEY_SM2 = 6,      // ✅ 新增
    KEY_BLISS = 7,    // ⚠️ 从 6 改为 7
};
```

**添加签名方案**:
```c
enum signature_scheme_t {
    SIGN_UNKNOWN,
    // ... 其他方案 ...
    SIGN_ED25519,
    SIGN_ED448,
    SIGN_SM2_WITH_SM3,  // ✅ 新增在 ED448 之后
    SIGN_BLISS_WITH_SHA2_256,
    // ... BLISS 其他方案 ...
};
```

#### 文件 2: `src/libstrongswan/credentials/keys/public_key.c`

**修改密钥类型字符串数组**:
```c
ENUM(key_type_names, KEY_ANY, KEY_BLISS,
    "ANY",
    "RSA",
    "ECDSA",
    "DSA",
    "ED25519",
    "ED448",
    "SM2",      // ✅ 新增
    "BLISS",
);
```

**修改签名方案字符串数组**:
```c
ENUM(signature_scheme_names, SIGN_UNKNOWN, SIGN_BLISS_WITH_SHA3_512,
    "UNKNOWN",
    // ... RSA 方案 ...
    // ... ECDSA 方案 ...
    "ED25519",
    "ED448",
    "SM2_WITH_SM3",  // ✅ 新增
    "BLISS_WITH_SHA2_256",
    "BLISS_WITH_SHA2_384",
    "BLISS_WITH_SHA2_512",
    "BLISS_WITH_SHA3_256",
    "BLISS_WITH_SHA3_384",
    "BLISS_WITH_SHA3_512",
);
```

#### 文件 3: `src/libstrongswan/crypto/hashers/hasher.h`

```c
enum hash_algorithm_t {
    HASH_UNKNOWN = 0,
    HASH_MD5 = 1,
    HASH_SHA1 = 2,
    HASH_SHA224 = 3,
    HASH_SHA256 = 4,
    HASH_SHA384 = 5,
    HASH_SHA512 = 6,
    HASH_SHA3_224 = 7,
    HASH_SHA3_256 = 8,
    HASH_SHA3_384 = 9,
    HASH_SHA3_512 = 10,
    HASH_SM3 = 11,  // ✅ 新增
};
```

#### 文件 4: `src/libstrongswan/crypto/crypters/crypter.h`

```c
enum encryption_algorithm_t {
    // ... 其他算法 ...
    ENCR_CHACHA20_POLY1305 = 25,
    ENCR_SM4_CBC = 26,  // ✅ 新增
    ENCR_SM4_GCM = 27,  // ✅ 新增
};
```

### 1.2 编译验证

```bash
# WSL 环境编译
cd /tmp/strongswan-gmsm-final2/strongswan-5.9.6
make clean
make -j4
sudo make install

# 验证符号
nm -D /usr/lib/ipsec/libstrongswan.so | grep signature_scheme_names
strings /usr/lib/ipsec/libstrongswan.so | grep SM2
```

**结果**:
- ✅ 编译成功,无错误
- ✅ `signature_scheme_names` 符号已导出
- ✅ `SM2_WITH_SM3` 字符串已包含在库中

---

## ⏳ 阶段二:gmsm 插件集成 (进行中)

### 2.1 插件源代码准备

**已完成的插件文件**:

```
src/libstrongswan/plugins/gmsm/
├── gmsm_plugin.h              # 插件头文件
├── gmsm_plugin.c              # 插件注册和初始化
├── gmsm_sm3_hasher.h          # SM3 哈希接口
├── gmsm_sm3_hasher.c          # SM3 哈希实现
├── gmsm_sm4_crypter.h         # SM4 加密接口
├── gmsm_sm4_crypter.c         # SM4 加密实现
├── gmsm_sm2_public_key.h      # SM2 公钥接口
├── gmsm_sm2_public_key.c      # SM2 公钥验证实现
├── gmsm_sm2_private_key.h     # SM2 私钥接口
└── gmsm_sm2_private_key.c     # SM2 私钥签名实现
```

**依赖库**: GmSSL 3.1.1
- 位置: `/usr/local/lib/libgmssl.so.3.1`
- 头文件: `/usr/local/include/gmssl/`

### 2.2 修改构建系统

#### 步骤 1: 修改 `configure.ac`

在 strongSwan 源码根目录的 `configure.ac` 中添加:

```bash
# 找到其他插件的定义位置(搜索 ARG_ENABL_SET),在合适位置添加:

ARG_ENABL_SET([gmsm],
    [enables the gmsm plugin for Chinese GM/T cryptography (SM2/SM3/SM4).])

# 在插件总结部分添加(搜索 ADD_PLUGIN):
ADD_PLUGIN([gmsm],               [s charon scepclient pki scripts nm cmd], [])
```

**位置建议**: 在 `openssl` 插件定义之后添加

#### 步骤 2: 修改 `src/libstrongswan/Makefile.am`

找到 `SUBDIRS` 部分,添加:

```makefile
if MONOLITHIC
  SUBDIRS += plugins/gmsm
endif

if USE_GMSM
  SUBDIRS += plugins/gmsm
endif
```

**位置**: 在现有插件子目录定义之后

#### 步骤 3: 创建 `src/libstrongswan/plugins/gmsm/Makefile.am`

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
	gmsm_sm3_hasher.h gmsm_sm3_hasher.c \
	gmsm_sm4_crypter.h gmsm_sm4_crypter.c \
	gmsm_sm2_public_key.h gmsm_sm2_public_key.c \
	gmsm_sm2_private_key.h gmsm_sm2_private_key.c

libstrongswan_gmsm_la_LDFLAGS = -module -avoid-version

# 链接 GmSSL 库
libstrongswan_gmsm_la_LIBADD = -lgmssl

# 如果 GmSSL 安装在非标准位置,需要添加:
libstrongswan_gmsm_la_CFLAGS = -I/usr/local/include
libstrongswan_gmsm_la_LDFLAGS += -L/usr/local/lib
```

### 2.3 重新生成构建脚本

```bash
cd /tmp/strongswan-gmsm-final2/strongswan-5.9.6

# 重新运行 autotools
./autogen.sh

# 配置编译选项
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --enable-gmsm \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp \
    --with-systemdsystemunitdir=no

# 编译
make clean
make -j$(nproc)

# 安装
sudo make install
```

### 2.4 验证插件编译

```bash
# 检查插件是否生成
ls -lh src/libstrongswan/plugins/gmsm/.libs/

# 应该看到:
# libstrongswan-gmsm.so -> libstrongswan-gmsm.so.0.0.0
# libstrongswan-gmsm.so.0 -> libstrongswan-gmsm.so.0.0.0
# libstrongswan-gmsm.so.0.0.0

# 检查符号
nm -D src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so | grep -E 'gmsm|sm2|sm3|sm4'
```

---

## 📅 阶段三:配置和测试 (待开始)

### 3.1 启用 gmsm 插件

#### 修改 `/etc/strongswan.conf`

```conf
charon {
    load_modular = yes
    
    plugins {
        # 加载 gmsm 插件
        gmsm {
            load = yes
        }
        
        # 保持其他插件配置
        openssl {
            load = yes
        }
    }
}
```

### 3.2 测试 SM3 哈希

创建测试脚本 `test-sm3.sh`:

```bash
#!/bin/bash
echo "Testing SM3 hasher..."

# 使用 pki 工具测试(如果支持)
echo "Hello, GM/T" | openssl dgst -sm3

# 或者使用 GmSSL 直接测试
echo "Hello, GM/T" | gmssl dgst -sm3
```

### 3.3 生成 SM2 密钥对

```bash
# 使用 pki 工具(strongSwan 集成后)
pki --gen --type sm2 --outform pem > sm2_key.pem

# 或使用 GmSSL
gmssl sm2keygen -pass 1234 -out sm2_key.pem -pubout sm2_pub.pem
```

### 3.4 创建 SM2 证书

```bash
# 自签名 CA 证书
pki --self --ca --lifetime 3650 \
    --in sm2_key.pem \
    --type sm2 \
    --digest sm3 \
    --dn "C=CN, O=Test Org, CN=StrongSwan GM Root CA" \
    --outform pem > ca_cert.pem

# 服务器证书
pki --gen --type sm2 --outform pem > server_key.pem

pki --issue --lifetime 1825 \
    --in server_key.pem \
    --type sm2 \
    --digest sm3 \
    --cacert ca_cert.pem \
    --cakey sm2_key.pem \
    --dn "C=CN, O=Test Org, CN=vpn.example.com" \
    --san vpn.example.com \
    --flag serverAuth \
    --outform pem > server_cert.pem
```

### 3.5 配置 IKEv2 使用国密算法

#### swanctl.conf 示例

```conf
connections {
    gm-vpn {
        version = 2
        
        # 使用国密算法提案
        proposals = sm4gcm128-sm3-modp2048
        
        local {
            auth = pubkey
            certs = server_cert.pem
            id = vpn.example.com
        }
        
        remote {
            auth = pubkey
        }
        
        children {
            net {
                # ESP 使用 SM4
                esp_proposals = sm4gcm128-sm3-modp2048
                local_ts = 0.0.0.0/0
            }
        }
    }
}

secrets {
    private {
        file = server_key.pem
    }
}
```

### 3.6 验证测试

```bash
# 启动 charon
sudo charon

# 加载配置
sudo swanctl --load-all

# 查看连接状态
sudo swanctl --list-conns

# 查看算法支持
sudo swanctl --list-algs

# 应该看到:
# Encryption: SM4_CBC SM4_GCM
# Integrity: HMAC_SM3
# Key Exchange: ...
# Signature: SM2_WITH_SM3
```

---

## 🔧 故障排除

### 问题 1: 找不到 libgmssl.so

**错误**:
```
error while loading shared libraries: libgmssl.so.3: cannot open shared object file
```

**解决**:
```bash
# 添加到 ld.so.conf
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/gmssl.conf
sudo ldconfig

# 或设置环境变量
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### 问题 2: 插件加载失败

**检查日志**:
```bash
# 启动 charon 时查看详细日志
sudo charon --debug-all 2

# 查看 syslog
sudo journalctl -u strongswan -f
```

**常见原因**:
- GmSSL 库未正确安装
- 插件编译时链接路径不正确
- strongswan.conf 配置错误

### 问题 3: SM2 证书验证失败

**检查证书**:
```bash
# 查看证书详情
openssl x509 -in ca_cert.pem -text -noout

# 或使用 GmSSL
gmssl certparse -in ca_cert.pem
```

---

## 📊 进度跟踪

| 阶段 | 任务 | 状态 | 完成时间 |
|------|------|------|---------|
| 阶段一 | 添加枚举定义 | ✅ 完成 | 2025-10-30 |
| 阶段一 | 修复 ENUM 宏 | ✅ 完成 | 2025-10-30 |
| 阶段一 | 编译验证 | ✅ 完成 | 2025-10-30 |
| 阶段一 | 推送到 GitHub | ✅ 完成 | 2025-10-30 |
| 阶段二 | 修改 configure.ac | ⏳ 进行中 | - |
| 阶段二 | 修改 Makefile.am | ⏳ 进行中 | - |
| 阶段二 | 创建插件 Makefile.am | ⏳ 进行中 | - |
| 阶段二 | 重新编译 | 📅 待开始 | - |
| 阶段三 | 配置启用插件 | 📅 待开始 | - |
| 阶段三 | 生成测试证书 | 📅 待开始 | - |
| 阶段三 | IKEv2 连接测试 | 📅 待开始 | - |

---

## 📚 参考资料

### strongSwan 文档
- [官方文档](https://docs.strongswan.org/)
- [插件开发指南](https://wiki.strongswan.org/projects/strongswan/wiki/PluginArchitecture)
- [编译配置](https://wiki.strongswan.org/projects/strongswan/wiki/Autoconf)

### GmSSL 文档
- [GmSSL GitHub](https://github.com/guanzhi/GmSSL)
- [SM2 算法说明](http://www.gmbz.org.cn/main/viewfile/2018011001400692565.html)
- [SM3 算法说明](http://www.gmbz.org.cn/main/viewfile/2018011001400692889.html)
- [SM4 算法说明](http://www.gmbz.org.cn/main/viewfile/2018011001400691002.html)

### 国密标准
- **GM/T 0003-2012**: SM2 椭圆曲线公钥密码算法
- **GM/T 0004-2012**: SM3 密码杂凑算法  
- **GM/T 0002-2012**: SM4 分组密码算法

---

## 📝 变更记录

### 2025-10-30
- ✅ 完成阶段一:枚举定义集成
- ✅ 解决 ENUM 宏验证问题
- ✅ 成功编译 strongSwan 5.9.6
- ✅ 推送代码到 GitHub
- 📝 创建本操作步骤文档

---

**下一步行动**: 执行阶段二的步骤 2.2 - 修改构建系统配置文件
