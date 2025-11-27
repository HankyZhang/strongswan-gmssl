/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 private key implementation using GmSSL
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Ge		*encoding = chunk_clone(chunk_create(buf, len));
		DBG2(DBG_LIB, "SM2 private key encoded to DER successfully, len=%zu", len);
		return TRUE;
	default:
		DBG1(DBG_LIB, "SM2 unsupported encoding type: %d", type);
		return FALSE;Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 */

#include "gmsm_sm2_private_key.h"
#include "gmsm_sm2_public_key.h"

#include <library.h>
#include <gmssl/sm2.h>
#include <gmssl/sm3.h>
#include <gmssl/pem.h>
#include <string.h>

typedef struct private_gmsm_sm2_private_key_t private_gmsm_sm2_private_key_t;

/**
 * Private data structure for SM2 private key
 */
struct private_gmsm_sm2_private_key_t {

	/**
	 * Public interface for this signer
	 */
	gmsm_sm2_private_key_t public;

	/**
	 * GmSSL SM2 key structure
	 */
	SM2_KEY key;

	/**
	 * TRUE if key is set
	 */
	bool key_set;

	/**
	 * Reference counter
	 */
	refcount_t ref;
};

METHOD(private_key_t, sign, bool,
	private_gmsm_sm2_private_key_t *this, signature_scheme_t scheme,
	void *params, chunk_t data, chunk_t *signature)
{
	uint8_t sig_buf[SM2_MAX_SIGNATURE_SIZE];
	size_t siglen = sizeof(sig_buf);
	uint8_t dgst[32];  /* SM3 digest */
	SM3_CTX sm3_ctx;
	const char *id = SM2_DEFAULT_ID;
	size_t idlen = strlen(SM2_DEFAULT_ID);

	if (!this->key_set)
	{
		DBG1(DBG_LIB, "SM2 private key not set");
		return FALSE;
	}

	switch (scheme)
	{
		case SIGN_SM2_WITH_SM3:
			/* Calculate SM3 digest with Z value (SM2 requires ID in signature) */
			if (sm2_compute_z(dgst, &this->key.public_key, id, idlen) != 1)
			{
				DBG1(DBG_LIB, "SM2 compute Z failed");
				return FALSE;
			}

			/* Hash Z || M */
			sm3_init(&sm3_ctx);
			sm3_update(&sm3_ctx, dgst, 32);  /* Z value */
			sm3_update(&sm3_ctx, data.ptr, data.len);  /* message */
			sm3_finish(&sm3_ctx, dgst);  /* final digest */

			/* Sign the digest with SM2 */
			if (sm2_sign(&this->key, dgst, sig_buf, &siglen) != 1)
			{
				DBG1(DBG_LIB, "SM2 signature generation failed");
				return FALSE;
			}

			DBG3(DBG_LIB, "SM2 signature generated, size: %zu", siglen);
			break;
		default:
			DBG1(DBG_LIB, "unsupported signature scheme %N", signature_scheme_names, scheme);
			return FALSE;
	}

	*signature = chunk_clone(chunk_create(sig_buf, siglen));
	return TRUE;
}

METHOD(private_key_t, decrypt, bool,
	private_gmsm_sm2_private_key_t *this, encryption_scheme_t scheme,
	void *params, chunk_t crypto, chunk_t *plain)
{
	uint8_t buf[SM2_MAX_PLAINTEXT_SIZE];
	size_t len;

	if (!this->key_set)
	{
		return FALSE;
	}

	if (sm2_decrypt(&this->key, crypto.ptr, crypto.len, buf, &len) != 1)
	{
		return FALSE;
	}

	*plain = chunk_clone(chunk_create(buf, len));
	return TRUE;
}

METHOD(private_key_t, get_type, key_type_t,
	private_gmsm_sm2_private_key_t *this)
{
	return KEY_SM2;
}

METHOD(private_key_t, get_keysize, int,
	private_gmsm_sm2_private_key_t *this)
{
	return 256;  /* SM2 uses 256-bit keys */
}

METHOD(private_key_t, get_public_key, public_key_t*,
	private_gmsm_sm2_private_key_t *this)
{
	public_key_t *public;
	chunk_t pubkey_data;
	#define SM2_PUBLIC_KEY_INFO_DER_SIZE 91
	uint8_t pubkey_buf[SM2_PUBLIC_KEY_INFO_DER_SIZE];
	uint8_t *p = pubkey_buf;
	size_t len = 0;

	if (!this->key_set)
	{
		DBG1(DBG_LIB, "SM2 get_public_key: key not set");
		return NULL;
	}

	/* Export public key as SubjectPublicKeyInfo DER */
	if (sm2_public_key_info_to_der(&this->key, &p, &len) != 1)
	{
		DBG1(DBG_LIB, "SM2 get_public_key: failed to export SubjectPublicKeyInfo");
		return NULL;
	}
	if (len > sizeof(pubkey_buf))
	{
		DBG1(DBG_LIB, "SM2 get_public_key: DER size mismatch: %zu > %d", len, sizeof(pubkey_buf));
		return NULL;
	}

	pubkey_data = chunk_clone(chunk_create(pubkey_buf, len));
	DBG2(DBG_LIB, "SM2 get_public_key: exported SubjectPublicKeyInfo, len=%zu", len);

	public = lib->creds->create(lib->creds, CRED_PUBLIC_KEY, KEY_SM2,
								BUILD_BLOB_ASN1_DER, pubkey_data,
								BUILD_END);
	chunk_free(&pubkey_data);
	return public;
}

METHOD(private_key_t, get_fingerprint, bool,
	private_gmsm_sm2_private_key_t *this, cred_encoding_type_t type,
	chunk_t *fingerprint)
{
	public_key_t *public;
	bool success;

	public = get_public_key(this);
	if (!public)
	{
		return FALSE;
	}
	success = public->get_fingerprint(public, type, fingerprint);
	public->destroy(public);

	return success;
}

METHOD(private_key_t, get_encoding, bool,
	private_gmsm_sm2_private_key_t *this, cred_encoding_type_t type,
	chunk_t *encoding)
{
	#define SM2_PRIVATE_KEY_INFO_DER_SIZE 150
	uint8_t buf[SM2_PRIVATE_KEY_INFO_DER_SIZE];
	uint8_t *p = buf;
	size_t len = 0;
	
	if (!this->key_set)
	{
		DBG1(DBG_LIB, "SM2 private key not set for encoding");
		return FALSE;
	}

	switch (type)
	{
		case PRIVKEY_ASN1_DER:
		case PRIVKEY_PEM:
			/* Export as PKCS#8 PrivateKeyInfo DER */
			if (sm2_private_key_info_to_der(&this->key, &p, &len) != 1)
			{
				DBG1(DBG_LIB, "SM2 private key DER encoding failed (sm2_private_key_info_to_der)");
				return FALSE;
			}
			if (len > sizeof(buf))
			{
				DBG1(DBG_LIB, "SM2 private key DER size mismatch: %zu > %d", len, sizeof(buf));
				return FALSE;
		}
		*encoding = chunk_clone(chunk_create(buf, len));
		DBG2(DBG_LIB, "SM2 private key encoded to DER successfully, len=%zu", len);
		return TRUE;
	default:
		DBG1(DBG_LIB, "SM2 unsupported encoding type: %d", type);
		return FALSE;
	}
}METHOD(private_key_t, get_ref, private_key_t*,
	private_gmsm_sm2_private_key_t *this)
{
	ref_get(&this->ref);
	return &this->public.key;
}

METHOD(private_key_t, destroy, void,
	private_gmsm_sm2_private_key_t *this)
{
	if (ref_put(&this->ref))
	{
		memwipe(&this->key, sizeof(SM2_KEY));
		free(this);
	}
}

/**
 * Generic private constructor
 */
static private_gmsm_sm2_private_key_t *gmsm_sm2_private_key_create_empty(void)
{
	private_gmsm_sm2_private_key_t *this;

	INIT(this,
		.public = {
			.key = {
				.get_type = _get_type,
				.sign = _sign,
				.decrypt = _decrypt,
				.get_keysize = _get_keysize,
				.get_public_key = _get_public_key,
				.equals = private_key_equals,
				.belongs_to = private_key_belongs_to,
				.get_fingerprint = _get_fingerprint,
				.has_fingerprint = private_key_has_fingerprint,
				.get_encoding = _get_encoding,
				.get_ref = _get_ref,
				.destroy = _destroy,
			},
		},
		.ref = 1,
		.key_set = FALSE,
	);

	return this;
}

/**
 * Described in header
 */
gmsm_sm2_private_key_t *gmsm_sm2_private_key_gen(key_type_t type, va_list args)
{
	private_gmsm_sm2_private_key_t *this;

	while (TRUE)
	{
		switch (va_arg(args, builder_part_t))
		{
			case BUILD_KEY_SIZE:
				/* SM2 key size is fixed at 256 bits */
				va_arg(args, u_int);
				continue;
			case BUILD_END:
				break;
			default:
				return NULL;
		}
		break;
	}

	this = gmsm_sm2_private_key_create_empty();

	/* Generate SM2 key pair */
	if (sm2_key_generate(&this->key) != 1)
	{
		destroy(this);
		return NULL;
	}

	this->key_set = TRUE;
	return &this->public;
}

/**
 * Described in header
 */
gmsm_sm2_private_key_t *gmsm_sm2_private_key_load(key_type_t type, va_list args)
{
	private_gmsm_sm2_private_key_t *this;
	chunk_t blob = chunk_empty;
	DBG1(DBG_LIB, "SM2 private loader entered (type=%d)", type);

	while (TRUE)
	{
		switch (va_arg(args, builder_part_t))
		{
			case BUILD_BLOB_ASN1_DER:
			case BUILD_BLOB_PEM:
				blob = va_arg(args, chunk_t);
				DBG1(DBG_LIB, "SM2 private loader got blob part len=%zu", blob.len);
				continue;
			case BUILD_END:
				break;
			default:
				return NULL;
		}
		break;
	}

	if (blob.len == 0)
	{
		return NULL;
	}

	this = gmsm_sm2_private_key_create_empty();

	DBG1(DBG_LIB, "SM2 load: received blob len=%zu", blob.len);
	/* 支持的格式顺序:
	 * 1) PEM PKCS#8 (sm2_private_key_info_from_pem)
	 * 2) PEM ECPrivateKey   (sm2_private_key_from_pem)
	 * 3) DER PKCS#8         (sm2_private_key_info_from_der)
	 * 4) DER ECPrivateKey   (sm2_private_key_from_der)
	 * 暂时移除原始私钥与复合格式回退, 以便缩小问题范围
	 */

	/* Create a memory FILE for PEM parsing if blob looks like text */
	bool looks_pem = blob.len > 16 && memchr(blob.ptr, '-', blob.len) && memchr(blob.ptr, '\n', blob.len);
	DBG1(DBG_LIB, "SM2 load: looks_pem=%d", looks_pem);
				if (looks_pem)
	{
		/* Log first line of PEM for diagnostics */
		char first_line[128];
		size_t i;
		for (i = 0; i < sizeof(first_line)-1 && i < blob.len; i++)
		{
			if (blob.ptr[i] == '\n' || blob.ptr[i] == '\r')
				break;
			first_line[i] = blob.ptr[i];
		}
		first_line[i] = '\0';
		DBG1(DBG_LIB, "SM2 load: PEM header line: %s", first_line);
	}
	else
	{
		/* Show first up to 32 bytes of DER hex */
		char hexbuf[3*32+1];
		size_t hlen = blob.len < 32 ? blob.len : 32;
		size_t j;
		for (j = 0; j < hlen; j++)
		{
			snprintf(hexbuf + 3*j, sizeof(hexbuf) - 3*j, "%02X ", blob.ptr[j]);
		}
		hexbuf[3*hlen] = '\0';
		DBG1(DBG_LIB, "SM2 load: DER first bytes: %s", hexbuf);
	}
	if (looks_pem)
	{
		char *tmp = NULL;
		FILE *fp = NULL;
		/* Ensure NUL termination */
		tmp = malloc(blob.len + 1);
		if (tmp)
		{
			memcpy(tmp, blob.ptr, blob.len);
			tmp[blob.len] = '\0';
			fp = fmemopen(tmp, blob.len, "r");
		}
		if (fp)
		{
			/* Try encrypted PKCS#8 with hardcoded passwords first */
			const char *passwords[] = {
				"123456",                    /* Common simple password - TRY FIRST */
				"",                          /* Empty password */
				"password",                  /* Default password */
				"1234",                      /* Very simple */
				"server1234", 
				"client1234", 
				"ca1234",
				"StrongGmsmPassword123!",   /* From swanctl config */
				"vpnserver",
				"vpnclient",
				NULL
			};
			for (int i = 0; passwords[i] != NULL && !this->key_set; i++)
			{
				/* Initialize key structure before each attempt */
				memset(&this->key, 0, sizeof(this->key));
				
				/* Skip empty password on second attempt - GmSSL HMAC bug workaround */
				if (i > 0 && passwords[i][0] == '\0')
				{
					DBG2(DBG_LIB, "SM2 load: skipping empty password attempt %d (GmSSL HMAC bug)", i);
					continue;
				}
				
				DBG2(DBG_LIB, "SM2 load: trying password index %d (len=%zu)", i, strlen(passwords[i]));
				int result = sm2_private_key_info_decrypt_from_pem(&this->key, passwords[i], fp);
				if (result == 1)
				{
					DBG1(DBG_LIB, "SM2 load: encrypted PKCS#8 PEM decrypted successfully with password (index=%d)", i);
					this->key_set = TRUE;
					break;
				}
				else
				{
					DBG2(DBG_LIB, "SM2 load: password attempt %d failed (result=%d)", i, result);
				}
				
				/* Safely rewind after failed attempt */
				if (fp && !feof(fp))
				{
					rewind(fp);
				}
			}

			/* Try unencrypted PKCS#8 */
			if (!this->key_set && sm2_private_key_info_from_pem(&this->key, fp) == 1)
			{
				DBG1(DBG_LIB, "SM2 load: PKCS#8 PEM parsed successfully");
				this->key_set = TRUE;
			}
			rewind(fp);

			/* Try traditional ECPrivateKey format */
			if (!this->key_set && sm2_private_key_from_pem(&this->key, fp) == 1)
			{
				DBG1(DBG_LIB, "SM2 load: traditional ECPrivateKey PEM parsed successfully");
				this->key_set = TRUE;
			}
			fclose(fp);
		}
		if (tmp)
		{
			free(tmp);
		}
	}

	if (!this->key_set)
	{
		/* Try DER variants */
		const uint8_t *p = blob.ptr;
		size_t len = blob.len;
		const uint8_t *attrs = NULL; /* ignore attributes */
		size_t attrs_len = 0;
		if (sm2_private_key_info_from_der(&this->key, &attrs, &attrs_len, &p, &len) == 1 && len == 0)
		{
			DBG1(DBG_LIB, "SM2 load: PKCS#8 DER parsed successfully");
			this->key_set = TRUE;
		}
		if (!this->key_set)
		{
			/* Reset pointer for second try */
			p = blob.ptr;
			len = blob.len;
						if (sm2_private_key_from_der(&this->key, &p, &len) == 1 && len == 0)
			{
				DBG1(DBG_LIB, "SM2 load: ECPrivateKey DER parsed successfully");
				this->key_set = TRUE;
			}
		}
	}

	if (!this->key_set)
	{
		DBG1(DBG_LIB, "SM2 load: all parsing attempts failed");
	}

	if (!this->key_set)
	{
	DBG1(DBG_LIB, "SM2 load: returning NULL (parse failure)");
	destroy(this);
	return NULL;
	}
	return &this->public;
}
