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
	 * Diffie-Hellman group number.
	 */
	diffie_hellman_group_t group;

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

METHOD(diffie_hellman_t, set_other_public_value, bool,
	private_gmsm_sm2_dh_t *this, chunk_t value)
{
	SM2_POINT peer_public;
	uint8_t shared_key[32];

	if (!value.len || value.len != 65)
	{
		DBG1(DBG_LIB, "invalid SM2 public value length: %zu", value.len);
		return FALSE;
	}

	/* Convert peer's public key from octets to SM2_POINT */
	if (sm2_point_from_uncompressed_octets(&peer_public, value.ptr) != 1)
	{
		DBG1(DBG_LIB, "failed to parse SM2 peer public key");
		return FALSE;
	}

	/* Perform SM2 key exchange to derive shared secret */
	/* Note: GmSSL sm2_ecdh uses the private key and peer's public key */
	if (sm2_ecdh(&this->private_key, &peer_public, shared_key) != 1)
	{
		DBG1(DBG_LIB, "SM2 ECDH failed");
		return FALSE;
	}

	chunk_free(&this->shared_secret);
	this->shared_secret = chunk_clone(chunk_create(shared_key, 32));

	DBG3(DBG_LIB, "SM2 DH shared secret computed");
	return TRUE;
}

METHOD(diffie_hellman_t, get_other_public_value, bool,
	private_gmsm_sm2_dh_t *this, chunk_t *value)
{
	/* Not typically used in strongSwan, but return our public value */
	*value = chunk_clone(chunk_create(this->public_value, 65));
	return TRUE;
}

METHOD(diffie_hellman_t, set_private_value, bool,
	private_gmsm_sm2_dh_t *this, chunk_t value)
{
	/* Generate new SM2 key pair */
	if (sm2_key_generate(&this->private_key) != 1)
	{
		DBG1(DBG_LIB, "SM2 key generation failed");
		return FALSE;
	}

	/* Extract public key as uncompressed octets */
	sm2_point_to_uncompressed_octets(&this->private_key.public_key, this->public_value);

	DBG3(DBG_LIB, "SM2 DH private/public key pair generated");
	return TRUE;
}

METHOD(diffie_hellman_t, get_my_public_value, bool,
	private_gmsm_sm2_dh_t *this, chunk_t *value)
{
	*value = chunk_clone(chunk_create(this->public_value, 65));
	return TRUE;
}

METHOD(diffie_hellman_t, get_shared_secret, bool,
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

METHOD(diffie_hellman_t, get_dh_group, diffie_hellman_group_t,
	private_gmsm_sm2_dh_t *this)
{
	return this->group;
}

METHOD(diffie_hellman_t, destroy, void,
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
gmsm_sm2_dh_t *gmsm_sm2_dh_create(diffie_hellman_group_t group, ...)
{
	private_gmsm_sm2_dh_t *this;

	/* Only support SM2 curve group (we'll use a custom group number) */
	if (group != SM2_256)
	{
		DBG1(DBG_LIB, "DH group %N not supported by SM2", 
			 diffie_hellman_group_names, group);
		return NULL;
	}

	INIT(this,
		.public = {
			.dh = {
				.get_shared_secret = _get_shared_secret,
				.set_other_public_value = _set_other_public_value,
				.get_my_public_value = _get_my_public_value,
				.set_private_value = _set_private_value,
				.get_dh_group = _get_dh_group,
				.destroy = _destroy,
			},
		},
		.group = group,
	);

	/* Generate initial key pair */
	if (!set_private_value(this, chunk_empty))
	{
		destroy(this);
		return NULL;
	}

	return &this->public;
}
