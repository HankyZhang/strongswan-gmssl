# SM2 证书开源库实现方案

## 🎯 核心发现

**是的，有现成的开源库可以帮助实现 SM2 证书解析！** 最佳选择是直接使用 **GmSSL 3.1.1** 的证书解析功能，而不是从零开始编写 ASN.1 解析器。

---

## 📚 可用的开源库方案

### 方案 1: GmSSL 库（推荐 ⭐⭐⭐⭐⭐）

**优势**:
- ✅ 已经安装（您的系统已有 GmSSL 3.1.1）
- ✅ 原生支持 SM2 证书解析
- ✅ 提供完整的 X.509 API
- ✅ 支持证书链验证
- ✅ 与现有 gmsm 插件无缝集成

**GmSSL 证书 API**:

```c
#include <gmssl/x509.h>
#include <gmssl/x509_ext.h>
#include <gmssl/pem.h>

// 1. 从 PEM 文件加载证书
int x509_cert_from_pem(X509_CERT *cert, FILE *fp);

// 2. 从 DER 数据加载证书
int x509_cert_from_der(X509_CERT *cert, const uint8_t **in, size_t *inlen);

// 3. 获取证书字段
int x509_cert_get_issuer(const X509_CERT *cert, uint8_t **d, size_t *dlen);
int x509_cert_get_subject(const X509_CERT *cert, uint8_t **d, size_t *dlen);
int x509_cert_get_subject_public_key(const X509_CERT *cert, SM2_KEY *public_key);

// 4. 验证证书签名
int x509_cert_verify_by_ca_cert(const X509_CERT *cert, 
                                  const X509_CERT *ca_cert,
                                  int depth);

// 5. 获取证书有效期
int x509_cert_get_not_before(const X509_CERT *cert, time_t *tv);
int x509_cert_get_not_after(const X509_CERT *cert, time_t *tv);
```

**示例代码**:

```c
// 加载 SM2 证书
FILE *fp = fopen("/etc/swanctl/x509/servercert.pem", "r");
X509_CERT cert;

if (x509_cert_from_pem(&cert, fp) != 1) {
    fprintf(stderr, "Failed to load certificate\n");
    return -1;
}
fclose(fp);

// 获取公钥
SM2_KEY public_key;
if (x509_cert_get_subject_public_key(&cert, &public_key) == 1) {
    printf("SM2 public key loaded successfully\n");
}

// 获取 Subject DN
uint8_t *subject_der;
size_t subject_len;
x509_cert_get_subject(&cert, &subject_der, &subject_len);

// 验证证书
X509_CERT ca_cert;
FILE *ca_fp = fopen("/etc/swanctl/x509ca/cacert.pem", "r");
x509_cert_from_pem(&ca_cert, ca_fp);
fclose(ca_fp);

if (x509_cert_verify_by_ca_cert(&cert, &ca_cert, 0) == 1) {
    printf("Certificate verified successfully\n");
}
```

---

### 方案 2: OpenSSL + GmSSL 插桥（备选 ⭐⭐⭐⭐）

**说明**: 使用 OpenSSL 的 X.509 API，但将 SM2 相关操作委托给 GmSSL。

**优势**:
- ✅ OpenSSL 的 X.509 API 更成熟
- ✅ strongSwan 已经使用 OpenSSL
- ✅ 只需处理 SM2 特定部分

**劣势**:
- ❌ 需要维护两套库的集成
- ❌ OpenSSL 1.1.1 对 SM2 支持不完整

---

### 方案 3: Tongsuo（国密 OpenSSL 分支）（备选 ⭐⭐⭐）

**说明**: 阿里巴巴维护的 OpenSSL 国密分支，完整支持 SM2/SM3/SM4。

**优势**:
- ✅ 完全兼容 OpenSSL API
- ✅ 原生支持 SM 算法
- ✅ 活跃维护（2024+ 更新）

**劣势**:
- ❌ 需要替换现有 OpenSSL
- ❌ 可能与 strongSwan 5.9.6 有兼容性问题

**仓库**: https://github.com/Tongsuo-Project/Tongsuo

---

## 🔧 推荐实现方案：使用 GmSSL X.509 API

### 架构设计

```
gmsm_sm2_cert.c (简化版)
  ├── 使用 GmSSL 的 x509_cert_from_pem() 加载证书
  ├── 使用 GmSSL 的 x509_cert_get_*() 提取字段
  ├── 转换为 strongSwan 的 certificate_t 接口
  └── 集成到 strongSwan 证书管理系统
```

### 核心代码（约 300-500 行，而不是 1000+ 行！）

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_sm2_cert.c`

```c
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 X.509 certificate using GmSSL library
 */

#include "gmsm_sm2_cert.h"
#include "gmsm_sm2_public_key.h"

#include <library.h>
#include <utils/debug.h>
#include <credentials/certificates/x509.h>

#include <gmssl/x509.h>
#include <gmssl/x509_ext.h>
#include <gmssl/pem.h>
#include <gmssl/error.h>

typedef struct private_gmsm_sm2_cert_t private_gmsm_sm2_cert_t;

/**
 * Private data
 */
struct private_gmsm_sm2_cert_t {
	
	/**
	 * Public interface
	 */
	gmsm_sm2_cert_t public;

	/**
	 * GmSSL certificate object
	 */
	X509_CERT gmssl_cert;

	/**
	 * Certificate encoding (DER)
	 */
	chunk_t encoding;

	/**
	 * Certificate encoding hash
	 */
	chunk_t encoding_hash;

	/**
	 * Issuer DN
	 */
	identification_t *issuer;

	/**
	 * Subject DN
	 */
	identification_t *subject;

	/**
	 * Subject alternative names
	 */
	linked_list_t *subjectAltNames;

	/**
	 * Embedded SM2 public key
	 */
	public_key_t *public_key;

	/**
	 * notBefore
	 */
	time_t notBefore;

	/**
	 * notAfter
	 */
	time_t notAfter;

	/**
	 * Serial number
	 */
	chunk_t serialNumber;

	/**
	 * Subject Key Identifier
	 */
	chunk_t subjectKeyIdentifier;

	/**
	 * Authority Key Identifier
	 */
	chunk_t authKeyIdentifier;

	/**
	 * Reference counter
	 */
	refcount_t ref;
};

/**
 * Convert GmSSL X509_NAME to strongSwan identification_t
 */
static identification_t* gmssl_name_to_id(const uint8_t *name_der, size_t len)
{
	chunk_t name_chunk = chunk_create((u_char*)name_der, len);
	return identification_create_from_encoding(ID_DER_ASN1_DN, name_chunk);
}

/**
 * Extract public key from GmSSL certificate
 */
static public_key_t* extract_public_key(private_gmsm_sm2_cert_t *this)
{
	SM2_KEY sm2_key;
	uint8_t key_buffer[1024];
	uint8_t *p = key_buffer;
	size_t key_len;

	/* Get SM2 public key from certificate */
	if (x509_cert_get_subject_public_key(&this->gmssl_cert, &sm2_key) != 1)
	{
		DBG1(DBG_LIB, "failed to extract SM2 public key from certificate");
		return NULL;
	}

	/* Encode SM2 public key to DER */
	key_len = 0;
	if (sm2_key_to_der(&sm2_key, &p, &key_len) != 1)
	{
		DBG1(DBG_LIB, "failed to encode SM2 public key");
		return NULL;
	}

	/* Create strongSwan public key from DER */
	chunk_t key_chunk = chunk_create(key_buffer, key_len);
	return lib->creds->create(lib->creds,
		CRED_PUBLIC_KEY, KEY_SM2,
		BUILD_BLOB_ASN1_DER, key_chunk,
		BUILD_END);
}

/**
 * Parse certificate using GmSSL
 */
static bool parse_certificate(private_gmsm_sm2_cert_t *this, chunk_t blob)
{
	const uint8_t *der = blob.ptr;
	size_t der_len = blob.len;
	uint8_t *issuer_der, *subject_der;
	size_t issuer_len, subject_len;
	time_t not_before, not_after;
	uint8_t serial[32];
	size_t serial_len;

	/* Parse DER encoded certificate using GmSSL */
	if (x509_cert_from_der(&this->gmssl_cert, &der, &der_len) != 1)
	{
		DBG1(DBG_LIB, "GmSSL failed to parse certificate");
		gmssl_print_errors();
		return FALSE;
	}

	/* Get issuer */
	if (x509_cert_get_issuer(&this->gmssl_cert, &issuer_der, &issuer_len) == 1)
	{
		this->issuer = gmssl_name_to_id(issuer_der, issuer_len);
		DBG2(DBG_LIB, "  issuer: '%Y'", this->issuer);
	}

	/* Get subject */
	if (x509_cert_get_subject(&this->gmssl_cert, &subject_der, &subject_len) == 1)
	{
		this->subject = gmssl_name_to_id(subject_der, subject_len);
		DBG2(DBG_LIB, "  subject: '%Y'", this->subject);
	}

	/* Get validity */
	if (x509_cert_get_not_before(&this->gmssl_cert, &not_before) == 1)
	{
		this->notBefore = not_before;
	}
	if (x509_cert_get_not_after(&this->gmssl_cert, &not_after) == 1)
	{
		this->notAfter = not_after;
	}

	/* Get serial number */
	if (x509_cert_get_serial_number(&this->gmssl_cert, serial, &serial_len) == 1)
	{
		this->serialNumber = chunk_clone(chunk_create(serial, serial_len));
	}

	/* Extract public key */
	this->public_key = extract_public_key(this);
	if (!this->public_key)
	{
		return FALSE;
	}

	/* Parse extensions (SubjectAltName, KeyIdentifiers, etc.) */
	// TODO: 使用 GmSSL 的 x509_cert_get_ext_*() 函数提取扩展

	return TRUE;
}

/**
 * Calculate certificate fingerprint
 */
static bool calc_fingerprint(private_gmsm_sm2_cert_t *this)
{
	hasher_t *hasher;

	hasher = lib->crypto->create_hasher(lib->crypto, HASH_SM3);
	if (!hasher)
	{
		DBG1(DBG_LIB, "SM3 hasher not available for fingerprint");
		return FALSE;
	}
	if (!hasher->allocate_hash(hasher, this->encoding, &this->encoding_hash))
	{
		hasher->destroy(hasher);
		return FALSE;
	}
	hasher->destroy(hasher);
	return TRUE;
}

METHOD(certificate_t, get_type, certificate_type_t,
	private_gmsm_sm2_cert_t *this)
{
	return CERT_X509;
}

METHOD(certificate_t, get_subject, identification_t*,
	private_gmsm_sm2_cert_t *this)
{
	return this->subject;
}

METHOD(certificate_t, get_issuer, identification_t*,
	private_gmsm_sm2_cert_t *this)
{
	return this->issuer;
}

METHOD(certificate_t, has_subject, id_match_t,
	private_gmsm_sm2_cert_t *this, identification_t *subject)
{
	if (this->subject->equals(this->subject, subject))
	{
		return ID_MATCH_PERFECT;
	}
	return ID_MATCH_NONE;
}

METHOD(certificate_t, has_issuer, id_match_t,
	private_gmsm_sm2_cert_t *this, identification_t *issuer)
{
	if (this->issuer->equals(this->issuer, issuer))
	{
		return ID_MATCH_PERFECT;
	}
	return ID_MATCH_NONE;
}

METHOD(certificate_t, issued_by, bool,
	private_gmsm_sm2_cert_t *this, certificate_t *issuer,
	signature_params_t **scheme)
{
	/* 使用 GmSSL 验证证书签名 */
	X509_CERT *ca_cert;
	gmsm_sm2_cert_t *gmssl_ca;

	if (issuer->get_type(issuer) != CERT_X509)
	{
		return FALSE;
	}

	/* 如果是 gmsm 证书，直接使用 GmSSL 验证 */
	if (issuer->issued_by == (void*)issued_by)
	{
		gmssl_ca = (gmsm_sm2_cert_t*)issuer;
		ca_cert = &((private_gmsm_sm2_cert_t*)gmssl_ca)->gmssl_cert;
		
		if (x509_cert_verify_by_ca_cert(&this->gmssl_cert, ca_cert, 0) == 1)
		{
			if (scheme)
			{
				*scheme = signature_params_clone(&(signature_params_t){
					.scheme = SIGN_SM2_WITH_SM3
				});
			}
			return TRUE;
		}
	}

	return FALSE;
}

METHOD(certificate_t, get_public_key, public_key_t*,
	private_gmsm_sm2_cert_t *this)
{
	return this->public_key->get_ref(this->public_key);
}

METHOD(certificate_t, get_validity, bool,
	private_gmsm_sm2_cert_t *this, time_t *when,
	time_t *not_before, time_t *not_after)
{
	time_t t = when ? *when : time(NULL);

	if (not_before)
	{
		*not_before = this->notBefore;
	}
	if (not_after)
	{
		*not_after = this->notAfter;
	}
	return (t >= this->notBefore && t <= this->notAfter);
}

METHOD(certificate_t, get_encoding, bool,
	private_gmsm_sm2_cert_t *this, cred_encoding_type_t type,
	chunk_t *encoding)
{
	if (type == CERT_ASN1_DER)
	{
		*encoding = chunk_clone(this->encoding);
		return TRUE;
	}
	return lib->encoding->encode(lib->encoding, type, NULL, encoding,
		CRED_PART_X509_ASN1_DER, this->encoding, CRED_PART_END);
}

METHOD(certificate_t, equals, bool,
	private_gmsm_sm2_cert_t *this, certificate_t *other)
{
	chunk_t encoding;
	bool equal;

	if (this == (private_gmsm_sm2_cert_t*)other)
	{
		return TRUE;
	}
	if (other->get_type(other) != CERT_X509)
	{
		return FALSE;
	}
	if (!other->get_encoding(other, CERT_ASN1_DER, &encoding))
	{
		return FALSE;
	}
	equal = chunk_equals(this->encoding, encoding);
	free(encoding.ptr);
	return equal;
}

METHOD(certificate_t, get_ref, certificate_t*,
	private_gmsm_sm2_cert_t *this)
{
	ref_get(&this->ref);
	return &this->public.x509.interface;
}

METHOD(certificate_t, destroy, void,
	private_gmsm_sm2_cert_t *this)
{
	if (ref_put(&this->ref))
	{
		DESTROY_IF(this->issuer);
		DESTROY_IF(this->subject);
		DESTROY_IF(this->public_key);
		this->subjectAltNames->destroy_offset(this->subjectAltNames,
			offsetof(identification_t, destroy));
		chunk_free(&this->encoding);
		chunk_free(&this->encoding_hash);
		chunk_free(&this->serialNumber);
		chunk_free(&this->subjectKeyIdentifier);
		chunk_free(&this->authKeyIdentifier);
		free(this);
	}
}

/* X.509 interface methods (simplified) */
METHOD(x509_t, get_flags, x509_flag_t,
	private_gmsm_sm2_cert_t *this)
{
	// TODO: 从扩展中提取 flags
	return X509_NONE;
}

METHOD(x509_t, get_serial, chunk_t,
	private_gmsm_sm2_cert_t *this)
{
	return this->serialNumber;
}

METHOD(x509_t, get_subjectKeyIdentifier, chunk_t,
	private_gmsm_sm2_cert_t *this)
{
	return this->subjectKeyIdentifier;
}

METHOD(x509_t, get_authKeyIdentifier, chunk_t,
	private_gmsm_sm2_cert_t *this)
{
	return this->authKeyIdentifier;
}

METHOD(x509_t, create_subjectAltName_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this)
{
	return this->subjectAltNames->create_enumerator(this->subjectAltNames);
}

METHOD(x509_t, create_crl_uri_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this)
{
	return enumerator_create_empty();
}

METHOD(x509_t, create_ocsp_uri_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this)
{
	return enumerator_create_empty();
}

METHOD(x509_t, create_ipAddrBlock_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this)
{
	return enumerator_create_empty();
}

METHOD(x509_t, create_name_constraint_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this, bool perm)
{
	return enumerator_create_empty();
}

METHOD(x509_t, create_cert_policy_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this)
{
	return enumerator_create_empty();
}

METHOD(x509_t, create_policy_mapping_enumerator, enumerator_t*,
	private_gmsm_sm2_cert_t *this)
{
	return enumerator_create_empty();
}

METHOD(x509_t, get_constraint, u_int,
	private_gmsm_sm2_cert_t *this, x509_constraint_t type)
{
	// TODO: 从扩展中提取约束
	return X509_NO_CONSTRAINT;
}

METHOD(x509_t, get_fingerprint, chunk_t,
	private_gmsm_sm2_cert_t *this, cred_encoding_type_t type)
{
	switch (type)
	{
		case KEYID_PUBKEY_SHA1:
		case KEYID_PUBKEY_INFO_SHA1:
			return this->encoding_hash;
		default:
			return chunk_empty;
	}
}

/**
 * See header
 */
gmsm_sm2_cert_t *gmsm_sm2_cert_load(certificate_type_t type, va_list args)
{
	private_gmsm_sm2_cert_t *this;
	chunk_t blob = chunk_empty;

	while (TRUE)
	{
		switch (va_arg(args, builder_part_t))
		{
			case BUILD_BLOB_ASN1_DER:
				blob = va_arg(args, chunk_t);
				continue;
			case BUILD_END:
				break;
			default:
				return NULL;
		}
		break;
	}

	if (!blob.ptr || type != CERT_X509)
	{
		return NULL;
	}

	INIT(this,
		.public = {
			.x509 = {
				.interface = {
					.get_type = _get_type,
					.get_subject = _get_subject,
					.get_issuer = _get_issuer,
					.has_subject = _has_subject,
					.has_issuer = _has_issuer,
					.issued_by = _issued_by,
					.get_public_key = _get_public_key,
					.get_validity = _get_validity,
					.get_encoding = _get_encoding,
					.equals = _equals,
					.get_ref = _get_ref,
					.destroy = _destroy,
				},
				.get_flags = _get_flags,
				.get_serial = _get_serial,
				.get_subjectKeyIdentifier = _get_subjectKeyIdentifier,
				.get_authKeyIdentifier = _get_authKeyIdentifier,
				.create_subjectAltName_enumerator = _create_subjectAltName_enumerator,
				.create_crl_uri_enumerator = _create_crl_uri_enumerator,
				.create_ocsp_uri_enumerator = _create_ocsp_uri_enumerator,
				.create_ipAddrBlock_enumerator = _create_ipAddrBlock_enumerator,
				.create_name_constraint_enumerator = _create_name_constraint_enumerator,
				.create_cert_policy_enumerator = _create_cert_policy_enumerator,
				.create_policy_mapping_enumerator = _create_policy_mapping_enumerator,
				.get_constraint = _get_constraint,
				.get_fingerprint = _get_fingerprint,
			},
		},
		.encoding = chunk_clone(blob),
		.subjectAltNames = linked_list_create(),
		.ref = 1,
	);

	if (!parse_certificate(this, blob))
	{
		destroy(this);
		return NULL;
	}

	if (!calc_fingerprint(this))
	{
		destroy(this);
		return NULL;
	}

	return &this->public;
}
```

---

## 📊 方案对比

| 特性 | 手写 ASN.1 解析 | 使用 GmSSL API | 使用 Tongsuo |
|------|----------------|---------------|-------------|
| **代码行数** | 1000+ 行 | 300-500 行 | 100-200 行 |
| **开发时间** | 8-16 小时 | 3-6 小时 | 2-4 小时 |
| **复杂度** | 高 | 中 | 低 |
| **维护性** | 难 | 中 | 易 |
| **依赖** | 无额外依赖 | GmSSL (已安装) | 需替换 OpenSSL |
| **可靠性** | 自己保证 | GmSSL 团队维护 | 阿里维护 |
| **推荐度** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🎯 最终推荐方案

### 推荐：使用 GmSSL X.509 API

**理由**:
1. ✅ **已有依赖**: GmSSL 3.1.1 已安装，无需额外下载
2. ✅ **代码简洁**: 300-500 行 vs 1000+ 行
3. ✅ **开发快速**: 3-6 小时 vs 8-16 小时
4. ✅ **质量保证**: GmSSL 团队维护的成熟代码
5. ✅ **完整功能**: 证书解析、验证、扩展提取都有现成 API

**修改后的 Makefile.am**:

```makefile
libstrongswan_gmsm_la_SOURCES = \
	gmsm_plugin.h gmsm_plugin.c \
	gmsm_sm3_hasher.h gmsm_sm3_hasher.c \
	gmsm_sm4_crypter.h gmsm_sm4_crypter.c \
	gmsm_sm2_private_key.h gmsm_sm2_private_key.c \
	gmsm_sm2_public_key.h gmsm_sm2_public_key.c \
	gmsm_sm2_cert.h gmsm_sm2_cert.c

libstrongswan_gmsm_la_CFLAGS = \
	-I$(top_srcdir)/src/libstrongswan \
	$(PLUGIN_CFLAGS)

libstrongswan_gmsm_la_LDFLAGS = \
	-module -avoid-version \
	-lgmssl  # 链接 GmSSL 库
```

---

## 📝 实施步骤（简化版）

### 1. 检查 GmSSL API 可用性

```bash
wsl bash -c "pkg-config --cflags --libs gmssl"
```

如果没有 pkg-config，手动检查：

```bash
wsl bash -c "ls -la /usr/local/include/gmssl/x509.h"
wsl bash -c "ls -la /usr/local/lib/libgmssl.so.3"
```

### 2. 创建测试程序验证 GmSSL API

```bash
wsl bash -c "cat > /tmp/test_gmssl_cert.c << 'EOF'
#include <stdio.h>
#include <gmssl/x509.h>
#include <gmssl/pem.h>

int main() {
    FILE *fp = fopen(\"/etc/swanctl/x509/servercert.pem\", \"r\");
    if (!fp) {
        fprintf(stderr, \"Cannot open certificate file\n\");
        return 1;
    }
    
    X509_CERT cert;
    if (x509_cert_from_pem(&cert, fp) != 1) {
        fprintf(stderr, \"Failed to parse certificate\n\");
        fclose(fp);
        return 1;
    }
    fclose(fp);
    
    printf(\"Certificate loaded successfully!\n\");
    
    uint8_t *subject;
    size_t subject_len;
    if (x509_cert_get_subject(&cert, &subject, &subject_len) == 1) {
        printf(\"Subject length: %zu bytes\n\", subject_len);
    }
    
    return 0;
}
EOF
gcc -o /tmp/test_gmssl_cert /tmp/test_gmssl_cert.c -lgmssl -I/usr/local/include -L/usr/local/lib
/tmp/test_gmssl_cert"
```

### 3. 创建实际的 gmsm_sm2_cert.c

使用上面提供的代码模板（300-500 行版本）

### 4. 修改插件注册

在 `gmsm_plugin.c` 中添加：

```c
#include "gmsm_sm2_cert.h"

// 在 get_features() 中添加:
PLUGIN_REGISTER(CERT_DECODE, gmsm_sm2_cert_load, TRUE),
    PLUGIN_PROVIDE(CERT_DECODE, CERT_X509),
        PLUGIN_DEPENDS(HASHER, HASH_SM3),
        PLUGIN_DEPENDS(PUBKEY, KEY_SM2),
```

### 5. 编译和测试

```bash
cd /mnt/c/Code/strongswan
wsl bash wsl-build-final-complete.sh
sudo swanctl --load-creds
```

---

## ⚡ 快速开始（立即可测试）

如果您想现在就开始，我可以帮您：

**选项 1**: 创建完整的 `gmsm_sm2_cert.c` 文件（使用 GmSSL API）

**选项 2**: 先测试 GmSSL 的 X.509 API 是否工作

**选项 3**: 查看 GmSSL 3.1.1 的完整 API 文档

您希望我现在执行哪个选项？ 🚀

---

## 📚 参考资料

### GmSSL 文档
- [X.509 API Reference](http://gmssl.org/docs/x509.html)
- [GitHub - GmSSL](https://github.com/guanzhi/GmSSL)
- [GmSSL 3.1.0 变更](https://github.com/guanzhi/GmSSL/releases/tag/v3.1.0)

### 其他开源项目
- [Tongsuo (BabaSSL)](https://github.com/Tongsuo-Project/Tongsuo)
- [OpenSSL SM2 Support](https://www.openssl.org/docs/man1.1.1/man7/SM2.html)

---

## ✅ 总结

**答案**: 是的，有开源库可以实现 SM2 证书！

**最佳方案**: 使用 **GmSSL 3.1.1 的 X.509 API**

**优势**:
- 代码量减少 60%（300 行 vs 1000 行）
- 开发时间减少 50%（3-6 小时 vs 8-16 小时）
- 质量更高（使用成熟的 GmSSL 解析器）
- 维护简单（GmSSL 团队维护）

**下一步**: 我可以立即为您创建基于 GmSSL API 的证书解析器实现，预计 30 分钟内完成核心代码。需要我现在开始吗？ 😊
