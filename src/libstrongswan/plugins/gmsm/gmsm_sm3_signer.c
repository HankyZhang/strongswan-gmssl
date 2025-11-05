/*
 * Copyright (C) 2025 HankyZhang
 * 
 * HMAC-SM3 signer implementation using GmSSL
 */

#include "gmsm_sm3_signer.h"
#include "gmsm_sm3_hasher.h"

#include <library.h>
#include <utils/debug.h>

#include <gmssl/hmac.h>
#include <gmssl/sm3.h>
#include <gmssl/digest.h>

typedef struct private_gmsm_sm3_signer_t private_gmsm_sm3_signer_t;

/**
 * Private data of gmsm_sm3_signer_t
 */
struct private_gmsm_sm3_signer_t {

	/**
	 * Public interface
	 */
	gmsm_sm3_signer_t public;

	/**
	 * GmSSL HMAC context
	 */
	HMAC_CTX hmac_ctx;

	/**
	 * Stored key for re-initialization
	 */
	chunk_t key;

	/**
	 * Truncation length for MAC (12 bytes for 96-bit)
	 */
	size_t trunc_len;
};

METHOD(signer_t, get_signature, bool,
	private_gmsm_sm3_signer_t *this, chunk_t data, uint8_t *buffer)
{
	uint8_t mac[SM3_HMAC_SIZE];
	size_t mac_len;

	if (buffer == NULL)
	{
		/* Process data without generating output (for incremental hashing) */
		hmac_update(&this->hmac_ctx, data.ptr, data.len);
		return TRUE;
	}

	/* Generate HMAC */
	hmac_update(&this->hmac_ctx, data.ptr, data.len);
	hmac_finish(&this->hmac_ctx, mac, &mac_len);

	/* Copy truncated MAC to output buffer */
	memcpy(buffer, mac, this->trunc_len);

	/* Re-initialize for next operation */
	hmac_init(&this->hmac_ctx, DIGEST_sm3(), this->key.ptr, this->key.len);

	return TRUE;
}

METHOD(signer_t, allocate_signature, bool,
	private_gmsm_sm3_signer_t *this, chunk_t data, chunk_t *chunk)
{
	if (chunk == NULL)
	{
		return get_signature(this, data, NULL);
	}

	chunk->ptr = malloc(this->trunc_len);
	chunk->len = this->trunc_len;

	return get_signature(this, data, chunk->ptr);
}

METHOD(signer_t, verify_signature, bool,
	private_gmsm_sm3_signer_t *this, chunk_t data, chunk_t signature)
{
	uint8_t mac[SM3_HMAC_SIZE];
	size_t mac_len;
	uint8_t *buffer;

	if (signature.len != this->trunc_len)
	{
		return FALSE;
	}

	/* Generate MAC */
	hmac_update(&this->hmac_ctx, data.ptr, data.len);
	hmac_finish(&this->hmac_ctx, mac, &mac_len);

	/* Re-initialize for next operation */
	hmac_init(&this->hmac_ctx, DIGEST_sm3(), this->key.ptr, this->key.len);

	/* Compare */
	buffer = signature.ptr;
	return memeq_const(buffer, mac, this->trunc_len);
}

METHOD(signer_t, get_key_size, size_t,
	private_gmsm_sm3_signer_t *this)
{
	return SM3_HMAC_SIZE; /* SM3 produces 256-bit (32-byte) output */
}

METHOD(signer_t, get_block_size, size_t,
	private_gmsm_sm3_signer_t *this)
{
	return SM3_BLOCK_SIZE; /* SM3 block size is 64 bytes */
}

METHOD(signer_t, set_key, bool,
	private_gmsm_sm3_signer_t *this, chunk_t key)
{
	/* Store key for re-initialization */
	chunk_clear(&this->key);
	this->key = chunk_clone(key);
	
	/* Initialize HMAC-SM3 with the provided key */
	hmac_init(&this->hmac_ctx, DIGEST_sm3(), key.ptr, key.len);
	return TRUE;
}

METHOD(signer_t, destroy, void,
	private_gmsm_sm3_signer_t *this)
{
	/* Clean up HMAC context and stored key */
	chunk_clear(&this->key);
	memwipe(&this->hmac_ctx, sizeof(this->hmac_ctx));
	free(this);
}

/*
 * Described in header
 */
signer_t *gmsm_sm3_signer_create(integrity_algorithm_t algo)
{
	private_gmsm_sm3_signer_t *this;

	switch (algo)
	{
		case AUTH_HMAC_SM3_96:
			INIT(this,
				.public = {
					.signer = {
						.get_signature = _get_signature,
						.allocate_signature = _allocate_signature,
						.verify_signature = _verify_signature,
						.get_key_size = _get_key_size,
						.get_block_size = _get_block_size,
						.set_key = _set_key,
						.destroy = _destroy,
					},
				},
				.trunc_len = 12, /* 96 bits = 12 bytes */
			);
			break;
		default:
			return NULL;
	}

	return &this->public.signer;
}
