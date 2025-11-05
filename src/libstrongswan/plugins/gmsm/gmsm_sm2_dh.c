/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM2 Diffie-Hellman key exchange using GmSSL
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 */

#include "gmsm_sm2_dh.h"

#include <library.h>
#include <gmssl/sm2.h>
#include <string.h>

typedef struct private_gmsm_sm2_dh_t private_gmsm_sm2_dh_t;

/**
 * Private data of gmsm_sm2_dh_t object.
 */
struct private_gmsm_sm2_dh_t {

	/**
	 * Public interface.
	 */
	gmsm_sm2_dh_t public;

	/**
	 * Key exchange method.
	 */
	key_exchange_method_t group;

	/**
	 * Private key for SM2 key exchange
	 */
	SM2_KEY private_key;

	/**
	 * Public key (our side)
	 */
	uint8_t public_value[65];  /* Uncompressed point: 0x04 || X || Y */

	/**
	 * Shared secret
	 */
	chunk_t shared_secret;
};

METHOD(key_exchange_t, set_public_key, bool,
	private_gmsm_sm2_dh_t *this, chunk_t value)
{
	SM2_POINT peer_point;
	uint8_t shared_key[32];

	if (!value.len || value.len != 65)
	{
		DBG1(DBG_LIB, "invalid SM2 public value length: %zu (expected 65)", value.len);
		return FALSE;
	}

	/* GmSSL 3.x sm2_ecdh signature: 
	 * int sm2_ecdh(const SM2_KEY *key, const uint8_t *peer_public, size_t peer_public_len, SM2_POINT *out) */
	if (sm2_ecdh(&this->private_key, value.ptr, value.len, &peer_point) != 1)
	{
		DBG1(DBG_LIB, "SM2 ECDH computation failed");
		return FALSE;
	}

	/* Extract X coordinate as shared secret (32 bytes) */
	memcpy(shared_key, &peer_point.x, 32);

	chunk_free(&this->shared_secret);
	this->shared_secret = chunk_clone(chunk_create(shared_key, 32));

	DBG3(DBG_LIB, "SM2 DH shared secret computed");
	return TRUE;
}

METHOD(key_exchange_t, get_public_key, bool,
	private_gmsm_sm2_dh_t *this, chunk_t *value)
{
	*value = chunk_clone(chunk_create(this->public_value, 65));
	return TRUE;
}

METHOD(key_exchange_t, get_shared_secret, bool,
	private_gmsm_sm2_dh_t *this, chunk_t *secret)
{
	if (!this->shared_secret.len)
	{
		DBG1(DBG_LIB, "SM2 DH shared secret not yet computed");
		return FALSE;
	}

	*secret = chunk_clone(this->shared_secret);
	return TRUE;
}

METHOD(key_exchange_t, get_method, key_exchange_method_t,
	private_gmsm_sm2_dh_t *this)
{
	return this->group;
}

METHOD(key_exchange_t, destroy, void,
	private_gmsm_sm2_dh_t *this)
{
	chunk_clear(&this->shared_secret);
	memwipe(&this->private_key, sizeof(SM2_KEY));
	memwipe(this->public_value, sizeof(this->public_value));
	free(this);
}

/*
 * Described in header
 */
gmsm_sm2_dh_t *gmsm_sm2_dh_create(key_exchange_method_t group, ...)
{
	private_gmsm_sm2_dh_t *this;

	/* Only support SM2 curve group */
	if (group != SM2_256)
	{
		DBG1(DBG_LIB, "Key exchange method %N not supported by SM2", 
			 key_exchange_method_names, group);
		return NULL;
	}

	INIT(this,
		.public = {
			.ke = {
				.get_shared_secret = _get_shared_secret,
				.set_public_key = _set_public_key,
				.get_public_key = _get_public_key,
				.get_method = _get_method,
				.destroy = _destroy,
			},
		},
		.group = group,
	);

	/* Generate initial SM2 key pair */
	if (sm2_key_generate(&this->private_key) != 1)
	{
		DBG1(DBG_LIB, "SM2 key generation failed");
		free(this);
		return NULL;
	}

	/* Extract public key as uncompressed octets */
	sm2_point_to_uncompressed_octets(&this->private_key.public_key, this->public_value);

	return &this->public;
}
