/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 public key implementation using GmSSL
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 */

#include "gmsm_sm2_public_key.h"

#include <library.h>
#include <gmssl/sm2.h>
#include <gmssl/sm3.h>
#include <string.h>

typedef struct private_gmsm_sm2_public_key_t private_gmsm_sm2_public_key_t;

/**
 * Private data structure for SM2 public key
 */
struct private_gmsm_sm2_public_key_t {

	/**
	 * Public interface for this verifier
	 */
	gmsm_sm2_public_key_t public;

	/**
	 * GmSSL SM2 key structure (public key only)
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

METHOD(public_key_t, verify, bool,
	private_gmsm_sm2_public_key_t *this, signature_scheme_t scheme,
	void *params, chunk_t data, chunk_t signature)
{
	uint8_t dgst[32];  /* SM3 digest */
	SM3_CTX sm3_ctx;
	const char *id = SM2_DEFAULT_ID;
	size_t idlen = strlen(SM2_DEFAULT_ID);

	if (!this->key_set)
	{
		DBG1(DBG_LIB, "SM2 public key not set");
		return FALSE;
	}

	switch (scheme)
	{
		case SIGN_SM2_WITH_SM3:
			/* Calculate SM3 digest with Z value (must match signing process) */
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

			/* Verify with SM2 */
			if (sm2_verify(&this->key, dgst, signature.ptr, signature.len) != 1)
			{
				DBG1(DBG_LIB, "SM2 signature verification failed");
				return FALSE;
			}

			DBG3(DBG_LIB, "SM2 signature verified successfully");
			break;
		default:
			DBG1(DBG_LIB, "unsupported signature scheme %N", signature_scheme_names, scheme);
			return FALSE;
	}

	return TRUE;
}

METHOD(public_key_t, encrypt, bool,
	private_gmsm_sm2_public_key_t *this, encryption_scheme_t scheme,
	void *params, chunk_t plain, chunk_t *crypto)
{
	uint8_t buf[SM2_MAX_CIPHERTEXT_SIZE];
	size_t len;

	if (!this->key_set)
	{
		return FALSE;
	}

	if (sm2_encrypt(&this->key, plain.ptr, plain.len, buf, &len) != 1)
	{
		return FALSE;
	}

	*crypto = chunk_clone(chunk_create(buf, len));
	return TRUE;
}

METHOD(public_key_t, get_type, key_type_t,
	private_gmsm_sm2_public_key_t *this)
{
	return KEY_SM2;
}

METHOD(public_key_t, get_keysize, int,
	private_gmsm_sm2_public_key_t *this)
{
	return 256;  /* SM2 uses 256-bit keys */
}

METHOD(public_key_t, get_fingerprint, bool,
	private_gmsm_sm2_public_key_t *this, cred_encoding_type_t type,
	chunk_t *fingerprint)
{
	hasher_t *hasher;
	chunk_t key;
	uint8_t public_key_bytes[65];

	if (!this->key_set)
	{
		return FALSE;
	}

	switch (type)
	{
		case KEYID_PUBKEY_SHA1:
			/* Use SM3 for fingerprint */
			/* Convert SM2_POINT to uncompressed octets (65 bytes: 0x04 + X + Y) */
			sm2_point_to_uncompressed_octets(&this->key.public_key, public_key_bytes);
			key = chunk_create(public_key_bytes, 65);
			hasher = lib->crypto->create_hasher(lib->crypto, HASH_SM3);
			if (!hasher ||
				!hasher->allocate_hash(hasher, key, fingerprint))
			{
				DESTROY_IF(hasher);
				return FALSE;
			}
			hasher->destroy(hasher);
			return TRUE;
		default:
			return FALSE;
	}
}

METHOD(public_key_t, get_encoding, bool,
	private_gmsm_sm2_public_key_t *this, cred_encoding_type_t type,
	chunk_t *encoding)
{
	/* TODO: Implement PEM/DER encoding */
	return FALSE;
}

METHOD(public_key_t, get_ref, public_key_t*,
	private_gmsm_sm2_public_key_t *this)
{
	ref_get(&this->ref);
	return &this->public.key;
}

METHOD(public_key_t, destroy, void,
	private_gmsm_sm2_public_key_t *this)
{
	if (ref_put(&this->ref))
	{
		memwipe(&this->key, sizeof(SM2_KEY));
		free(this);
	}
}

/**
 * Described in header
 */
gmsm_sm2_public_key_t *gmsm_sm2_public_key_load(key_type_t type, va_list args)
{
	private_gmsm_sm2_public_key_t *this;
	chunk_t blob = chunk_empty;
	DBG1(DBG_LIB, "SM2 public loader entered (type=%d)", type);

	while (TRUE)
	{
		switch (va_arg(args, builder_part_t))
		{
			case BUILD_BLOB_ASN1_DER:
			case BUILD_BLOB_PEM:
				blob = va_arg(args, chunk_t);
				DBG1(DBG_LIB, "SM2 public loader got blob part len=%zu", blob.len);
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

	INIT(this,
		.public = {
			.key = {
				.get_type = _get_type,
				.verify = _verify,
				.encrypt = _encrypt,
				.equals = public_key_equals,
				.get_keysize = _get_keysize,
				.get_fingerprint = _get_fingerprint,
				.has_fingerprint = public_key_has_fingerprint,
				.get_encoding = _get_encoding,
				.get_ref = _get_ref,
				.destroy = _destroy,
			},
		},
		.ref = 1,
		.key_set = FALSE,
	);

	DBG1(DBG_LIB, "SM2 public load: blob len=%zu", blob.len);
	bool looks_pem = blob.len > 16 && memchr(blob.ptr, '-', blob.len) && memchr(blob.ptr, '\n', blob.len);
	DBG1(DBG_LIB, "SM2 public load: looks_pem=%d", looks_pem);
	if (looks_pem)
	{
		char first_line[128];
		size_t i;
		for (i = 0; i < sizeof(first_line)-1 && i < blob.len; i++)
		{
			if (blob.ptr[i] == '\n' || blob.ptr[i] == '\r')
				break;
			first_line[i] = blob.ptr[i];
		}
		first_line[i] = '\0';
		DBG1(DBG_LIB, "SM2 public load: PEM header line: %s", first_line);
	}
	else
	{
		char hexbuf[3*32+1];
		size_t hlen = blob.len < 32 ? blob.len : 32;
		size_t j;
		for (j = 0; j < hlen; j++)
		{
			snprintf(hexbuf + 3*j, sizeof(hexbuf) - 3*j, "%02X ", blob.ptr[j]);
		}
		hexbuf[3*hlen] = '\0';
		DBG1(DBG_LIB, "SM2 public load: DER first bytes: %s", hexbuf);
	}
	if (looks_pem)
	{
		char *tmp = malloc(blob.len + 1);
		if (tmp)
		{
			memcpy(tmp, blob.ptr, blob.len);
			tmp[blob.len] = '\0';
			FILE *fp = fmemopen(tmp, blob.len, "r");
			if (fp)
			{
				if (sm2_public_key_info_from_pem(&this->key, fp) == 1)
				{
					DBG1(DBG_LIB, "SM2 public load: PEM SubjectPublicKeyInfo parsed successfully");
					this->key_set = TRUE;
				}
				fclose(fp);
			}
			free(tmp);
		}
	}

	if (!this->key_set)
	{
		const uint8_t *p = blob.ptr;
		size_t len = blob.len;
		if (sm2_public_key_info_from_der(&this->key, &p, &len) == 1 && len == 0)
		{
			DBG1(DBG_LIB, "SM2 public load: DER SubjectPublicKeyInfo parsed successfully");
			this->key_set = TRUE;
		}
	}

	if (!this->key_set)
	{
		DBG1(DBG_LIB, "SM2 public load: parse failure");
		destroy(this);
		return NULL;
	}
	return &this->public;
}
