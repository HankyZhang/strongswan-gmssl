# SM2 证书支持实现方案

## 📋 概述

本文档详细说明如何在 strongSwan 的 gmsm 插件中添加 SM2 证书解析和加载功能。

**当前状态**:
- ✅ SM2 私钥/公钥支持已实现
- ✅ SM2 签名验证功能已实现
- ❌ SM2 证书解析功能缺失（导致无法加载 SM2 证书）

**目标**:
- ✅ 能够加载 GmSSL 生成的 SM2 证书
- ✅ 解析 SM2 证书中的公钥、DN、扩展等信息
- ✅ 支持 SM2 证书链验证
- ✅ 集成到现有的 strongSwan 证书管理系统

---

## 🔍 问题分析

### 当前错误

```bash
$ sudo swanctl --load-creds
loading certificate from '/etc/swanctl/x509/servercert.pem' failed
parsing X509 certificate failed
```

### 根本原因

1. **缺少 CERT_DECODE 注册**: gmsm 插件没有注册 X.509 证书解析功能
2. **SM2 OID 未识别**: strongSwan 的 ASN.1 解析器不认识 SM2 的 OID
3. **SM3 签名算法未识别**: 证书签名使用 SM3withSM2，但 strongSwan 不支持

### SM2 证书特征

GmSSL 生成的 SM2 证书使用以下 OID：

```asn1
算法 OID (AlgorithmIdentifier):
- SM2 公钥算法: 1.2.156.10197.1.301
- SM3withSM2 签名: 1.2.156.10197.1.501
- SM2 椭圆曲线: 1.2.156.10197.1.301 (SM2)

Subject Public Key Info:
- algorithm: 1.2.156.10197.1.301 (SM2)
- subjectPublicKey: BIT STRING (65 bytes, 0x04 + 32 bytes X + 32 bytes Y)

Signature Algorithm:
- algorithm: 1.2.156.10197.1.501 (SM3withSM2)
- parameters: NULL
```

---

## 📁 实现架构

### 文件结构

```
src/libstrongswan/plugins/gmsm/
├── gmsm_plugin.c           # 插件注册 (需要修改)
├── gmsm_plugin.h           # 插件头文件
├── gmsm_sm2_cert.c         # 新增：SM2 证书实现
├── gmsm_sm2_cert.h         # 新增：SM2 证书头文件
├── gmsm_oid.c              # 新增：SM OID 定义
├── gmsm_oid.h              # 新增：SM OID 头文件
├── gmsm_sm2_private_key.c
├── gmsm_sm2_public_key.c
├── gmsm_sm3_hasher.c
├── gmsm_sm4_crypter.c
└── Makefile.am             # 需要修改
```

### 依赖关系

```
gmsm_sm2_cert.c
  ├── 依赖: gmsm_sm2_public_key.c (加载公钥)
  ├── 依赖: gmsm_sm3_hasher.c (计算证书指纹)
  ├── 依赖: gmsm_oid.c (识别 SM2/SM3 OID)
  ├── 依赖: asn1/asn1_parser.h (ASN.1 解析)
  └── 依赖: credentials/certificates/x509.h (X.509 接口)
```

---

## 🔧 实现步骤

### 步骤 1: 创建 SM OID 定义

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_oid.h`

```c
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * GmSSL OID definitions for Chinese SM algorithms
 */

#ifndef GMSM_OID_H_
#define GMSM_OID_H_

#include <asn1/oid.h>

/*
 * SM2 公钥算法 OID: 1.2.156.10197.1.301
 */
#define OID_SM2_PUBKEY 0x2A, 0x81, 0x1C, 0xCF, 0x55, 0x01, 0x82, 0x2D

/*
 * SM3withSM2 签名算法 OID: 1.2.156.10197.1.501
 */
#define OID_SM2_WITH_SM3 0x2A, 0x81, 0x1C, 0xCF, 0x55, 0x01, 0x83, 0x75

/*
 * SM3 哈希算法 OID: 1.2.156.10197.1.401
 */
#define OID_SM3 0x2A, 0x81, 0x1C, 0xCF, 0x55, 0x01, 0x83, 0x11

/*
 * SM4 对称加密 OID: 1.2.156.10197.1.104
 */
#define OID_SM4_CBC 0x2A, 0x81, 0x1C, 0xCF, 0x55, 0x01, 0x68

/**
 * 检查 OID 是否为 SM2 公钥算法
 */
bool gmsm_oid_is_sm2_pubkey(chunk_t oid);

/**
 * 检查 OID 是否为 SM3withSM2 签名算法
 */
bool gmsm_oid_is_sm2_with_sm3(chunk_t oid);

/**
 * 检查 OID 是否为 SM3 哈希算法
 */
bool gmsm_oid_is_sm3(chunk_t oid);

#endif /** GMSM_OID_H_ @}*/
```

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_oid.c`

```c
/*
 * Copyright (C) 2025 HankyZhang
 */

#include "gmsm_oid.h"

#include <library.h>

/* SM2 公钥算法 OID: 1.2.156.10197.1.301 */
static u_char oid_sm2_pubkey[] = { OID_SM2_PUBKEY };

/* SM3withSM2 签名算法 OID: 1.2.156.10197.1.501 */
static u_char oid_sm2_with_sm3[] = { OID_SM2_WITH_SM3 };

/* SM3 哈希算法 OID: 1.2.156.10197.1.401 */
static u_char oid_sm3[] = { OID_SM3 };

/**
 * See header
 */
bool gmsm_oid_is_sm2_pubkey(chunk_t oid)
{
	return chunk_equals(oid, chunk_from_thing(oid_sm2_pubkey));
}

/**
 * See header
 */
bool gmsm_oid_is_sm2_with_sm3(chunk_t oid)
{
	return chunk_equals(oid, chunk_from_thing(oid_sm2_with_sm3));
}

/**
 * See header
 */
bool gmsm_oid_is_sm3(chunk_t oid)
{
	return chunk_equals(oid, chunk_from_thing(oid_sm3));
}
```

---

### 步骤 2: 创建 SM2 证书解析器头文件

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_sm2_cert.h`

```c
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 X.509 certificate parser
 */

/**
 * @defgroup gmsm_sm2_cert gmsm_sm2_cert
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM2_CERT_H_
#define GMSM_SM2_CERT_H_

typedef struct gmsm_sm2_cert_t gmsm_sm2_cert_t;

#include <credentials/builder.h>
#include <credentials/certificates/certificate.h>
#include <credentials/certificates/x509.h>

/**
 * Implementation of x509_t using GmSSL for SM2 certificates
 */
struct gmsm_sm2_cert_t {

	/**
	 * Implements the x509_t interface
	 */
	x509_t x509;
};

/**
 * Load an SM2 X.509 certificate
 *
 * This function takes BUILD_BLOB_ASN1_DER
 *
 * @param type		certificate type, CERT_X509 only
 * @param args		builder_part_t argument list
 * @return			SM2 X.509 certificate, NULL on failure
 */
gmsm_sm2_cert_t *gmsm_sm2_cert_load(certificate_type_t type, va_list args);

#endif /** GMSM_SM2_CERT_H_ @}*/
```

---

### 步骤 3: 实现 SM2 证书解析器（简化版）

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_sm2_cert.c`

由于完整实现需要约 1000+ 行代码，这里提供核心框架：

```c
/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 X.509 certificate implementation
 */

#include "gmsm_sm2_cert.h"
#include "gmsm_oid.h"
#include "gmsm_sm2_public_key.h"
#include "gmsm_sm3_hasher.h"

#include <library.h>
#include <asn1/asn1.h>
#include <asn1/asn1_parser.h>
#include <utils/identification.h>
#include <collections/linked_list.h>

typedef struct private_gmsm_sm2_cert_t private_gmsm_sm2_cert_t;

/**
 * Private data of an gmsm_sm2_cert_t object
 */
struct private_gmsm_sm2_cert_t {

	/**
	 * Public interface
	 */
	gmsm_sm2_cert_t public;

	/**
	 * X.509 certificate encoding in ASN.1 DER format
	 */
	chunk_t encoding;

	/**
	 * SHA256 hash of the certificate encoding
	 */
	chunk_t encoding_hash;

	/**
	 * X.509 certificate body (TBSCertificate)
	 */
	chunk_t tbsCertificate;

	/**
	 * Certificate version
	 */
	u_int version;

	/**
	 * Serial number
	 */
	chunk_t serialNumber;

	/**
	 * Issuer distinguished name
	 */
	identification_t *issuer;

	/**
	 * Subject distinguished name
	 */
	identification_t *subject;

	/**
	 * Subject alternative names
	 */
	linked_list_t *subjectAltNames;

	/**
	 * notBefore time
	 */
	time_t notBefore;

	/**
	 * notAfter time
	 */
	time_t notAfter;

	/**
	 * Embedded SM2 public key
	 */
	public_key_t *public_key;

	/**
	 * Subject Key Identifier
	 */
	chunk_t subjectKeyIdentifier;

	/**
	 * Authority Key Identifier
	 */
	chunk_t authKeyIdentifier;

	/**
	 * Signature algorithm (should be SM3withSM2)
	 */
	int signature_scheme;

	/**
	 * Signature value
	 */
	chunk_t signature;

	/**
	 * Reference counter
	 */
	refcount_t ref;
};

/**
 * ASN.1 definition of X.509 certificate
 */
static asn1Object_t certObjects[] = {
	{ 0, "certificate",				ASN1_SEQUENCE,		ASN1_OBJ  }, /*  0 */
	{ 1,   "tbsCertificate",		ASN1_SEQUENCE,		ASN1_OBJ  }, /*  1 */
	{ 2,     "DEFAULT v1",			ASN1_CONTEXT_C_0,	ASN1_DEF  }, /*  2 */
	{ 3,       "version",			ASN1_INTEGER,		ASN1_BODY }, /*  3 */
	{ 2,     "serialNumber",		ASN1_INTEGER,		ASN1_BODY }, /*  4 */
	{ 2,     "signature",			ASN1_EOC,			ASN1_RAW  }, /*  5 */
	{ 2,     "issuer",				ASN1_SEQUENCE,		ASN1_OBJ  }, /*  6 */
	{ 2,     "validity",			ASN1_SEQUENCE,		ASN1_NONE }, /*  7 */
	{ 3,       "notBefore",			ASN1_EOC,			ASN1_RAW  }, /*  8 */
	{ 3,       "notAfter",			ASN1_EOC,			ASN1_RAW  }, /*  9 */
	{ 2,     "subject",				ASN1_SEQUENCE,		ASN1_OBJ  }, /* 10 */
	{ 2,     "subjectPublicKeyInfo",ASN1_SEQUENCE,		ASN1_NONE }, /* 11 */
	{ 3,       "algorithm",			ASN1_EOC,			ASN1_RAW  }, /* 12 */
	{ 3,       "subjectPublicKey",	ASN1_BIT_STRING,	ASN1_NONE }, /* 13 */
	{ 4,         "sm2PublicKey",	ASN1_EOC,			ASN1_RAW  }, /* 14 */
	{ 2,     "extensions",			ASN1_CONTEXT_C_3,	ASN1_OPT  }, /* 15 */
	{ 2,     "end extensions",		ASN1_EOC,			ASN1_END  }, /* 16 */
	{ 1,   "signatureAlgorithm",	ASN1_EOC,			ASN1_RAW  }, /* 17 */
	{ 1,   "signatureValue",		ASN1_BIT_STRING,	ASN1_BODY }, /* 18 */
	{ 0, "exit",					ASN1_EOC,			ASN1_EXIT }
};

#define CERT_OBJ_CERTIFICATE				 0
#define CERT_OBJ_TBS_CERTIFICATE			 1
#define CERT_OBJ_VERSION					 3
#define CERT_OBJ_SERIAL_NUMBER				 4
#define CERT_OBJ_SIG_ALG					 5
#define CERT_OBJ_ISSUER						 6
#define CERT_OBJ_NOT_BEFORE					 8
#define CERT_OBJ_NOT_AFTER					 9
#define CERT_OBJ_SUBJECT					10
#define CERT_OBJ_SUBJECT_PUBLIC_KEY_ALGORITHM 12
#define CERT_OBJ_SUBJECT_PUBLIC_KEY			14
#define CERT_OBJ_EXTENSIONS					15
#define CERT_OBJ_SIGNATURE_ALGORITHM		17
#define CERT_OBJ_SIGNATURE					18

/**
 * Parse the time field
 */
static bool parse_time(chunk_t blob, time_t *time)
{
	asn1_t type;
	type = blob.ptr[0];
	
	if (type == ASN1_UTCTIME || type == ASN1_GENERALIZEDTIME)
	{
		return asn1_to_time(&blob, type, time);
	}
	return FALSE;
}

/**
 * Parse certificate extensions (simplified version)
 */
static bool parse_extensions(private_gmsm_sm2_cert_t *this, chunk_t blob)
{
	/* 简化实现：跳过扩展解析 */
	DBG1(DBG_LIB, "SM2 certificate extensions parsing not fully implemented");
	return TRUE;
}

/**
 * Parse the certificate
 */
static bool parse_certificate(private_gmsm_sm2_cert_t *this)
{
	asn1_parser_t *parser;
	chunk_t object;
	int objectID;
	bool success = FALSE;

	parser = asn1_parser_create(certObjects, this->encoding);

	while (parser->iterate(parser, &objectID, &object))
	{
		switch (objectID)
		{
			case CERT_OBJ_TBS_CERTIFICATE:
				this->tbsCertificate = object;
				break;
			case CERT_OBJ_VERSION:
				this->version = (object.len) ? (1 + (u_int)*object.ptr) : 1;
				DBG2(DBG_LIB, "  v%d", this->version);
				break;
			case CERT_OBJ_SERIAL_NUMBER:
				this->serialNumber = chunk_clone(object);
				break;
			case CERT_OBJ_SIG_ALG:
			{
				/* 检查签名算法是否为 SM3withSM2 */
				chunk_t oid = object;
				if (asn1_unwrap(&oid, &oid) == ASN1_SEQUENCE)
				{
					if (asn1_unwrap(&oid, &oid) == ASN1_OID)
					{
						if (!gmsm_oid_is_sm2_with_sm3(oid))
						{
							DBG1(DBG_LIB, "  signature algorithm is not SM3withSM2");
							goto end;
						}
						this->signature_scheme = SIGN_SM2_WITH_SM3;
					}
				}
				break;
			}
			case CERT_OBJ_ISSUER:
				this->issuer = identification_create_from_encoding(ID_DER_ASN1_DN, object);
				DBG2(DBG_LIB, "  '%Y'", this->issuer);
				break;
			case CERT_OBJ_NOT_BEFORE:
				if (!parse_time(object, &this->notBefore))
				{
					goto end;
				}
				break;
			case CERT_OBJ_NOT_AFTER:
				if (!parse_time(object, &this->notAfter))
				{
					goto end;
				}
				break;
			case CERT_OBJ_SUBJECT:
				this->subject = identification_create_from_encoding(ID_DER_ASN1_DN, object);
				DBG2(DBG_LIB, "  '%Y'", this->subject);
				break;
			case CERT_OBJ_SUBJECT_PUBLIC_KEY_ALGORITHM:
			{
				/* 检查公钥算法是否为 SM2 */
				chunk_t oid = object;
				if (asn1_unwrap(&oid, &oid) == ASN1_SEQUENCE)
				{
					if (asn1_unwrap(&oid, &oid) == ASN1_OID)
					{
						if (!gmsm_oid_is_sm2_pubkey(oid))
						{
							DBG1(DBG_LIB, "  public key algorithm is not SM2");
							goto end;
						}
					}
				}
				break;
			}
			case CERT_OBJ_SUBJECT_PUBLIC_KEY:
			{
				/* 加载 SM2 公钥 */
				this->public_key = lib->creds->create(lib->creds, 
					CRED_PUBLIC_KEY, KEY_SM2,
					BUILD_BLOB_ASN1_DER, object,
					BUILD_END);
				if (!this->public_key)
				{
					DBG1(DBG_LIB, "  failed to load SM2 public key");
					goto end;
				}
				break;
			}
			case CERT_OBJ_EXTENSIONS:
				if (!parse_extensions(this, object))
				{
					goto end;
				}
				break;
			case CERT_OBJ_SIGNATURE:
				this->signature = chunk_clone(object);
				break;
		}
	}
	success = parser->success(parser);

end:
	parser->destroy(parser);
	return success;
}

/**
 * Calculate the fingerprint of the certificate
 */
static bool calc_fingerprint(private_gmsm_sm2_cert_t *this)
{
	hasher_t *hasher;

	hasher = lib->crypto->create_hasher(lib->crypto, HASH_SM3);
	if (!hasher)
	{
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
	if (subject->get_type(subject) == ID_KEY_ID)
	{
		if (this->subjectKeyIdentifier.ptr &&
			chunk_equals(this->subjectKeyIdentifier, subject->get_encoding(subject)))
		{
			return ID_MATCH_PERFECT;
		}
	}
	else
	{
		if (this->subject->equals(this->subject, subject))
		{
			return ID_MATCH_PERFECT;
		}
	}
	return ID_MATCH_NONE;
}

METHOD(certificate_t, has_issuer, id_match_t,
	private_gmsm_sm2_cert_t *this, identification_t *issuer)
{
	return this->issuer->equals(this->issuer, issuer) ? ID_MATCH_PERFECT : ID_MATCH_NONE;
}

METHOD(certificate_t, issued_by, bool,
	private_gmsm_sm2_cert_t *this, certificate_t *issuer, signature_params_t **scheme)
{
	public_key_t *key;
	signature_params_t params = { .scheme = SIGN_SM2_WITH_SM3 };
	bool valid;

	/* 验证签名 */
	key = issuer->get_public_key(issuer);
	if (!key)
	{
		return FALSE;
	}
	
	valid = key->verify(key, this->signature_scheme, &params,
						this->tbsCertificate, this->signature);
	key->destroy(key);
	
	if (valid && scheme)
	{
		*scheme = signature_params_clone(&params);
	}
	return valid;
}

METHOD(certificate_t, get_public_key, public_key_t*,
	private_gmsm_sm2_cert_t *this)
{
	return this->public_key->get_ref(this->public_key);
}

METHOD(certificate_t, get_validity, bool,
	private_gmsm_sm2_cert_t *this, time_t *when, time_t *not_before, time_t *not_after)
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
	private_gmsm_sm2_cert_t *this, cred_encoding_type_t type, chunk_t *encoding)
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
	if (other->equals == (void*)equals)
	{
		return chunk_equals(this->encoding, ((private_gmsm_sm2_cert_t*)other)->encoding);
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
		chunk_free(&this->signature);
		free(this);
	}
}

/* X.509 interface methods (simplified) */
METHOD(x509_t, get_flags, x509_flag_t,
	private_gmsm_sm2_cert_t *this)
{
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

	if (!parse_certificate(this))
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

### 步骤 4: 修改插件注册

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_plugin.c`

在 `get_features` 函数中添加证书解析注册：

```c
#include "gmsm_sm2_cert.h"  // 在文件开头添加

METHOD(plugin_t, get_features, int,
	private_gmsm_plugin_t *this, plugin_feature_t *features[])
{
	static plugin_feature_t f[] = {
		/* SM3 hasher */
		PLUGIN_REGISTER(HASHER, gmsm_sm3_hasher_create),
			PLUGIN_PROVIDE(HASHER, HASH_SM3),
		/* SM4 crypter */
		PLUGIN_REGISTER(CRYPTER, gmsm_sm4_crypter_create),
			PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CBC, 16),
			PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_GCM_ICV16, 16),
		/* SM2 private key */
		PLUGIN_REGISTER(PRIVKEY, gmsm_sm2_private_key_load, TRUE),
			PLUGIN_PROVIDE(PRIVKEY, KEY_SM2),
				PLUGIN_PROVIDE(PRIVKEY_SIGN, SIGN_SM2_WITH_SM3),
		PLUGIN_REGISTER(PRIVKEY_GEN, gmsm_sm2_private_key_gen, FALSE),
			PLUGIN_PROVIDE(PRIVKEY_GEN, KEY_SM2),
		/* SM2 public key */
		PLUGIN_REGISTER(PUBKEY, gmsm_sm2_public_key_load, TRUE),
			PLUGIN_PROVIDE(PUBKEY, KEY_SM2),
				PLUGIN_PROVIDE(PUBKEY_VERIFY, SIGN_SM2_WITH_SM3),
		
		/* 新增: SM2 X.509 证书解析 */
		PLUGIN_REGISTER(CERT_DECODE, gmsm_sm2_cert_load, TRUE),
			PLUGIN_PROVIDE(CERT_DECODE, CERT_X509),
				PLUGIN_DEPENDS(HASHER, HASH_SM3),
				PLUGIN_DEPENDS(PUBKEY, KEY_SM2),
	};
	*features = f;
	return countof(f);
}
```

---

### 步骤 5: 修改 Makefile

**文件**: `src/libstrongswan/plugins/gmsm/Makefile.am`

```makefile
# ... 现有内容 ...

libstrongswan_gmsm_la_SOURCES = \
	gmsm_plugin.h gmsm_plugin.c \
	gmsm_sm3_hasher.h gmsm_sm3_hasher.c \
	gmsm_sm4_crypter.h gmsm_sm4_crypter.c \
	gmsm_sm2_private_key.h gmsm_sm2_private_key.c \
	gmsm_sm2_public_key.h gmsm_sm2_public_key.c \
	gmsm_oid.h gmsm_oid.c \
	gmsm_sm2_cert.h gmsm_sm2_cert.c

# ... 其余内容保持不变 ...
```

---

## 📝 编译和测试

### 1. 编译插件

```bash
cd /mnt/c/Code/strongswan
wsl bash wsl-build-final-complete.sh
```

### 2. 验证证书加载

```bash
# 生成 SM2 证书 (使用修复后的脚本)
sudo bash generate-sm2-certs.sh

# 加载证书
sudo swanctl --load-creds

# 期望输出:
# loaded certificate 'C=CN, O=Test, CN=server'
```

### 3. 查看证书详情

```bash
sudo swanctl --list-certs
```

期望输出:
```
  subject:  "C=CN, O=Test, CN=server"
  issuer:   "C=CN, O=Test CA, CN=CA"
  validity:  not before Oct 30 12:00:00 2025, ok
             not after  Oct 30 12:00:00 2026, ok (expires in 365 days)
  serial:    01:23:45:67:89:ab:cd:ef
  altNames:  server.example.com
  pubkey:    SM2 256 bits
  keyid:     xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
  subjkeyId: xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
  authkeyId: yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy:yy
```

---

## 🔍 技术细节

### ASN.1 解析流程

```
1. 读取 DER 编码的证书文件
2. 解析 Certificate SEQUENCE
   ├── TBSCertificate (待签名证书)
   │   ├── version
   │   ├── serialNumber
   │   ├── signature (签名算法 OID: SM3withSM2)
   │   ├── issuer (DN)
   │   ├── validity (notBefore, notAfter)
   │   ├── subject (DN)
   │   ├── subjectPublicKeyInfo
   │   │   ├── algorithm (OID: SM2)
   │   │   └── subjectPublicKey (65 bytes: 0x04 + X + Y)
   │   └── extensions (可选)
   ├── signatureAlgorithm (OID: SM3withSM2)
   └── signatureValue (BIT STRING)
3. 提取 SM2 公钥
4. 计算证书指纹 (SM3 hash)
5. 创建证书对象
```

### SM2 公钥格式

```
SubjectPublicKeyInfo ::= SEQUENCE {
  algorithm         AlgorithmIdentifier, -- OID: 1.2.156.10197.1.301
  subjectPublicKey  BIT STRING           -- 0x04 + 32字节X + 32字节Y
}

公钥数据结构:
- 第1字节: 0x04 (未压缩点)
- 第2-33字节: X 坐标 (32 bytes)
- 第34-65字节: Y 坐标 (32 bytes)
```

### 签名验证流程

```
1. 提取 TBSCertificate (待签名数据)
2. 提取签名值 (signatureValue)
3. 获取签发者的公钥
4. 使用 SM2 验证函数:
   verify(public_key, SIGN_SM2_WITH_SM3, TBSCertificate, signature)
5. 返回验证结果
```

---

## ⚠️ 注意事项

### 1. OID 识别

确保 SM2/SM3 的 OID 正确：
- SM2 公钥: `1.2.156.10197.1.301`
- SM3withSM2: `1.2.156.10197.1.501`
- SM3 哈希: `1.2.156.10197.1.401`

### 2. 证书链验证

需要确保：
- CA 证书已加载到 `/etc/swanctl/x509ca/`
- 服务器证书在 `/etc/swanctl/x509/`
- 私钥在 `/etc/swanctl/private/`

### 3. 扩展字段

上述实现简化了扩展字段解析，生产环境需要完整实现：
- subjectAltName
- keyUsage
- extendedKeyUsage
- basicConstraints
- subjectKeyIdentifier
- authorityKeyIdentifier

### 4. 性能考虑

- 证书解析是一次性操作，不影响 VPN 运行时性能
- 建议缓存已解析的证书对象
- SM3 哈希计算比 SHA256 略慢（约 10-20%）

---

## 📚 参考资料

### strongSwan 文档

- [Certificate Plugin Development](https://docs.strongswan.org/)
- [ASN.1 Parser API](https://github.com/strongswan/strongswan/tree/master/src/libstrongswan/asn1)
- [X.509 Plugin Implementation](https://github.com/strongswan/strongswan/tree/master/src/libstrongswan/plugins/x509)

### GmSSL 文档

- [SM2 证书格式](http://gmssl.org/docs/sm2-cert.html)
- [GmSSL API 参考](http://gmssl.org/docs/api.html)

### 国密标准

- GM/T 0009-2012: SM2 椭圆曲线公钥密码算法
- GM/T 0010-2012: SM2 密码算法应用
- GM/T 0015-2012: 数字证书格式

---

## 🎯 下一步

实现完成后，可以进行：

1. **证书认证的 VPN 连接**
   ```
   proposals = aes256-sha256-modp2048
   auth = pubkey
   certs = servercert.pem
   ```

2. **双向认证**
   - 服务器端使用 SM2 证书
   - 客户端使用 SM2 证书
   - 相互验证身份

3. **证书链验证**
   - 支持多级 CA
   - CRL 检查
   - OCSP 验证

4. **完整的 SM 算法栈**
   ```
   proposals = sm4-sm3-modp2048
   auth = pubkey (SM2 证书)
   ```

---

## ✅ 总结

通过以上步骤，您可以：

1. ✅ 加载 GmSSL 生成的 SM2 证书
2. ✅ 解析证书中的 SM2 公钥
3. ✅ 验证 SM3withSM2 签名
4. ✅ 集成到 strongSwan 证书管理系统

**预估工作量**: 8-16 小时

**难度**: 中高（需要理解 ASN.1、X.509 结构和 strongSwan 插件架构）

**收益**: 完整的 SM2 证书认证支持，实现端到端的国密算法应用

需要我帮您实际创建这些文件并编译测试吗？🚀
