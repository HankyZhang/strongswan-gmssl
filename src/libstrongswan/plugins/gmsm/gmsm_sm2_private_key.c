/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 private key implementation using GmSSL
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
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
	uint8_t pubkey_buf[65];  /* 04 || X || Y */

	if (!this->key_set)
	{
		return NULL;
	}

	/* Extract public key from SM2_KEY - convert SM2_POINT to uncompressed octets */
	sm2_point_to_uncompressed_octets(&this->key.public_key, pubkey_buf);
	pubkey_data = chunk_create(pubkey_buf, 65);

	public = lib->creds->create(lib->creds, CRED_PUBLIC_KEY, KEY_SM2,
								BUILD_BLOB_ASN1_DER, pubkey_data,
								BUILD_END);
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
	/* TODO: Implement PEM/DER encoding */
	return FALSE;
}

METHOD(private_key_t, get_ref, private_key_t*,
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

	while (TRUE)
	{
		switch (va_arg(args, builder_part_t))
		{
			case BUILD_BLOB_ASN1_DER:
			case BUILD_BLOB_PEM:
				blob = va_arg(args, chunk_t);
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

	/* Try PEM first */
	SM2_KEY sm2_tmp;
	memset(&sm2_tmp, 0, sizeof(sm2_tmp));
	BIO *bio = BIO_new_mem_buf(blob.ptr, blob.len);
	if (bio)
	{
		/* Attempt to read unencrypted PKCS#8 or traditional SM2 PEM */
		EVP_PKEY *pkey = PEM_read_bio_PrivateKey(bio, NULL, NULL, NULL);
		if (pkey)
		{
			/* Extract EC key assuming SM2 curve */
			EC_KEY *ec = EVP_PKEY_get1_EC_KEY(pkey);
			if (ec)
			{
				const EC_GROUP *group = EC_KEY_get0_group(ec);
				const EC_POINT *point = EC_KEY_get0_public_key(ec);
				const BIGNUM *priv = EC_KEY_get0_private_key(ec);
				if (group && point && priv)
				{
					/* Convert EC_POINT to octets */
					uint8_t buf[65];
					size_t len = EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED, buf, sizeof(buf), NULL);
					if (len == 65)
					{
						/* Set key values into GmSSL SM2_KEY structure */
						if (sm2_key_set_private_key(&this->key, priv) == 1 && sm2_key_set_public_key(&this->key, buf, len) == 1)
						{
							this->key_set = TRUE;
						}
					}
				}
				EC_KEY_free(ec);
			}
			EVP_PKEY_free(pkey);
		}
		BIO_free(bio);
	}
	if (!this->key_set)
	{
		/* Fall back: treat blob as raw (unsupported), fail gracefully */
		destroy(this);
		return NULL;
	}
	return &this->public;
}
