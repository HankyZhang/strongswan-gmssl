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

#include <gmssl/sm2.h>
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

	if (!this->key_set)
	{
		return FALSE;
	}

	switch (scheme)
	{
		case SIGN_SM2_WITH_SM3:
			/* Calculate SM3 digest */
			sm3_init(&sm3_ctx);
			sm3_update(&sm3_ctx, data.ptr, data.len);
			sm3_finish(&sm3_ctx, dgst);

			/* Verify with SM2 */
			if (sm2_verify(&this->key, dgst, signature.ptr, signature.len) != 1)
			{
				return FALSE;
			}
			break;
		default:
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

	if (!this->key_set)
	{
		return FALSE;
	}

	switch (type)
	{
		case KEYID_PUBKEY_SHA1:
			/* Use SM3 for fingerprint */
			key = chunk_create(this->key.public_key, 65);
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

	/* TODO: Parse PEM/DER format and load into SM2_KEY */
	/* For now, just fail gracefully */
	destroy(this);
	return NULL;
}
