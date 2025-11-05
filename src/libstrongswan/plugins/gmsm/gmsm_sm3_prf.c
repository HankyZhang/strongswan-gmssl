/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM3 PRF implementation using GmSSL
 */

#include "gmsm_sm3_prf.h"

#include <library.h>
#include <utils/debug.h>

#include <gmssl/hmac.h>
#include <gmssl/sm3.h>
#include <gmssl/digest.h>

typedef struct private_gmsm_sm3_prf_t private_gmsm_sm3_prf_t;

/**
 * Private data of gmsm_sm3_prf_t
 */
struct private_gmsm_sm3_prf_t {

	/**
	 * Public interface
	 */
	gmsm_sm3_prf_t public;

	/**
	 * GmSSL HMAC context
	 */
	HMAC_CTX hmac_ctx;

	/**
	 * Stored key for re-initialization
	 */
	chunk_t key;
};

METHOD(prf_t, get_bytes, bool,
	private_gmsm_sm3_prf_t *this, chunk_t seed, uint8_t *buffer)
{
	size_t mac_len;
	
	if (buffer == NULL)
	{
		/* Process seed without generating output (for incremental hashing) */
		hmac_update(&this->hmac_ctx, seed.ptr, seed.len);
		return TRUE;
	}

	/* Generate PRF output */
	hmac_update(&this->hmac_ctx, seed.ptr, seed.len);
	hmac_finish(&this->hmac_ctx, buffer, &mac_len);

	/* Re-initialize for next operation */
	hmac_init(&this->hmac_ctx, DIGEST_sm3(), this->key.ptr, this->key.len);

	return TRUE;
}

METHOD(prf_t, allocate_bytes, bool,
	private_gmsm_sm3_prf_t *this, chunk_t seed, chunk_t *chunk)
{
	if (chunk == NULL)
	{
		return get_bytes(this, seed, NULL);
	}

	chunk->ptr = malloc(SM3_HMAC_SIZE);
	chunk->len = SM3_HMAC_SIZE;

	return get_bytes(this, seed, chunk->ptr);
}

METHOD(prf_t, get_block_size, size_t,
	private_gmsm_sm3_prf_t *this)
{
	return SM3_BLOCK_SIZE; /* SM3 block size is 64 bytes */
}

METHOD(prf_t, get_key_size, size_t,
	private_gmsm_sm3_prf_t *this)
{
	return SM3_HMAC_SIZE; /* SM3 produces 256-bit (32-byte) output */
}

METHOD(prf_t, set_key, bool,
	private_gmsm_sm3_prf_t *this, chunk_t key)
{
	/* Store key for re-initialization */
	chunk_clear(&this->key);
	this->key = chunk_clone(key);
	
	/* Initialize HMAC-SM3 with the provided key */
	hmac_init(&this->hmac_ctx, DIGEST_sm3(), key.ptr, key.len);
	return TRUE;
}

METHOD(prf_t, destroy, void,
	private_gmsm_sm3_prf_t *this)
{
	/* Clean up HMAC context and stored key */
	chunk_clear(&this->key);
	memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));
	free(this);
}

/*
 * Described in header
 */
prf_t *gmsm_sm3_prf_create(pseudo_random_function_t algo)
{
	private_gmsm_sm3_prf_t *this;

	switch (algo)
	{
		case PRF_HMAC_SM3:
			INIT(this,
				.public = {
					.prf = {
						.get_bytes = _get_bytes,
						.allocate_bytes = _allocate_bytes,
						.get_block_size = _get_block_size,
						.get_key_size = _get_key_size,
						.set_key = _set_key,
						.destroy = _destroy,
					},
				},
			);
			break;
		default:
			return NULL;
	}

	return &this->public.prf;
}
