/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM4 crypter implementation using GmSSL
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 */

#include "gmsm_sm4_crypter.h"

#include <gmssl/sm4.h>
#include <string.h>

/* SM4_BLOCK_SIZE and SM4_KEY_SIZE are already defined in gmssl/sm4.h */

typedef struct private_gmsm_sm4_crypter_t private_gmsm_sm4_crypter_t;

/**
 * Private data structure with crypter context for SM4
 */
struct private_gmsm_sm4_crypter_t {

	/**
	 * Public interface for this crypter
	 */
	gmsm_sm4_crypter_t public;

	/**
	 * GmSSL SM4 encryption key
	 */
	SM4_KEY encrypt_key;

	/**
	 * GmSSL SM4 decryption key
	 */
	SM4_KEY decrypt_key;

	/**
	 * Encryption algorithm (CBC or GCM)
	 */
	encryption_algorithm_t algo;

	/**
	 * Key has been set
	 */
	bool key_set;
};

METHOD(crypter_t, encrypt, bool,
	private_gmsm_sm4_crypter_t *this, chunk_t data, chunk_t iv,
	chunk_t *encrypted)
{
	uint8_t *in, *out;
	uint8_t iv_copy[SM4_BLOCK_SIZE];

	if (!this->key_set)
	{
		return FALSE;
	}

	if (data.len % SM4_BLOCK_SIZE != 0)
	{
		return FALSE;
	}

	if (iv.len != SM4_BLOCK_SIZE)
	{
		return FALSE;
	}

	/* Copy IV as GmSSL modifies it */
	memcpy(iv_copy, iv.ptr, SM4_BLOCK_SIZE);

	if (encrypted)
	{
		*encrypted = chunk_alloc(data.len);
		out = encrypted->ptr;
	}
	else
	{
		out = data.ptr;
	}
	in = data.ptr;

	switch (this->algo)
	{
		case ENCR_SM4_CBC:
			sm4_cbc_encrypt(&this->encrypt_key, iv_copy, 
						   in, data.len / SM4_BLOCK_SIZE, out);
			break;
		default:
			return FALSE;
	}

	return TRUE;
}

METHOD(crypter_t, decrypt, bool,
	private_gmsm_sm4_crypter_t *this, chunk_t data, chunk_t iv,
	chunk_t *decrypted)
{
	uint8_t *in, *out;
	uint8_t iv_copy[SM4_BLOCK_SIZE];

	if (!this->key_set)
	{
		return FALSE;
	}

	if (data.len % SM4_BLOCK_SIZE != 0)
	{
		return FALSE;
	}

	if (iv.len != SM4_BLOCK_SIZE)
	{
		return FALSE;
	}

	/* Copy IV as GmSSL modifies it */
	memcpy(iv_copy, iv.ptr, SM4_BLOCK_SIZE);

	if (decrypted)
	{
		*decrypted = chunk_alloc(data.len);
		out = decrypted->ptr;
	}
	else
	{
		out = data.ptr;
	}
	in = data.ptr;

	switch (this->algo)
	{
		case ENCR_SM4_CBC:
			sm4_cbc_decrypt(&this->decrypt_key, iv_copy,
						   in, data.len / SM4_BLOCK_SIZE, out);
			break;
		default:
			return FALSE;
	}

	return TRUE;
}

METHOD(crypter_t, get_block_size, size_t,
	private_gmsm_sm4_crypter_t *this)
{
	return SM4_BLOCK_SIZE;
}

METHOD(crypter_t, get_iv_size, size_t,
	private_gmsm_sm4_crypter_t *this)
{
	return SM4_BLOCK_SIZE;
}

METHOD(crypter_t, get_key_size, size_t,
	private_gmsm_sm4_crypter_t *this)
{
	return SM4_KEY_SIZE;
}

METHOD(crypter_t, set_key, bool,
	private_gmsm_sm4_crypter_t *this, chunk_t key)
{
	if (key.len != SM4_KEY_SIZE)
	{
		return FALSE;
	}

	sm4_set_encrypt_key(&this->encrypt_key, key.ptr);
	sm4_set_decrypt_key(&this->decrypt_key, key.ptr);
	this->key_set = TRUE;

	return TRUE;
}

METHOD(crypter_t, destroy, void,
	private_gmsm_sm4_crypter_t *this)
{
	memwipe(&this->encrypt_key, sizeof(SM4_KEY));
	memwipe(&this->decrypt_key, sizeof(SM4_KEY));
	free(this);
}

/**
 * Described in header
 */
gmsm_sm4_crypter_t *gmsm_sm4_crypter_create(encryption_algorithm_t algo,
											size_t key_size)
{
	private_gmsm_sm4_crypter_t *this;

	if (key_size != SM4_KEY_SIZE)
	{
		return NULL;
	}

	switch (algo)
	{
		case ENCR_SM4_CBC:
			/* SM4-CBC is supported */
			break;
		default:
			/* Other modes not implemented yet */
			return NULL;
	}

	INIT(this,
		.public = {
			.crypter = {
				.encrypt = _encrypt,
				.decrypt = _decrypt,
				.get_block_size = _get_block_size,
				.get_iv_size = _get_iv_size,
				.get_key_size = _get_key_size,
				.set_key = _set_key,
				.destroy = _destroy,
			},
		},
		.algo = algo,
		.key_set = FALSE,
	);

	return &this->public;
}
