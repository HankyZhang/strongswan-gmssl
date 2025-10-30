/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM3 hasher implementation using GmSSL
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 */

#include "gmsm_sm3_hasher.h"

#include <gmssl/sm3.h>
#include <string.h>

typedef struct private_gmsm_sm3_hasher_t private_gmsm_sm3_hasher_t;

/**
 * Private data structure with hashing context for SM3
 */
struct private_gmsm_sm3_hasher_t {

	/**
	 * Public interface for this hasher
	 */
	gmsm_sm3_hasher_t public;

	/**
	 * GmSSL SM3 context
	 */
	SM3_CTX ctx;
};

METHOD(hasher_t, reset, bool,
	private_gmsm_sm3_hasher_t *this)
{
	sm3_init(&this->ctx);
	return TRUE;
}

METHOD(hasher_t, get_hash, bool,
	private_gmsm_sm3_hasher_t *this, chunk_t chunk, uint8_t *hash)
{
	sm3_update(&this->ctx, chunk.ptr, chunk.len);
	if (hash)
	{
		sm3_finish(&this->ctx, hash);
		sm3_init(&this->ctx);
	}
	return TRUE;
}

METHOD(hasher_t, allocate_hash, bool,
	private_gmsm_sm3_hasher_t *this, chunk_t chunk, chunk_t *hash)
{
	if (hash)
	{
		*hash = chunk_alloc(HASH_SIZE_SM3);
		return get_hash(this, chunk, hash->ptr);
	}
	return get_hash(this, chunk, NULL);
}

METHOD(hasher_t, get_hash_size, size_t,
	private_gmsm_sm3_hasher_t *this)
{
	return HASH_SIZE_SM3;
}

METHOD(hasher_t, destroy, void,
	private_gmsm_sm3_hasher_t *this)
{
	memwipe(&this->ctx, sizeof(SM3_CTX));
	free(this);
}

/**
 * Described in header
 */
gmsm_sm3_hasher_t *gmsm_sm3_hasher_create(hash_algorithm_t algo)
{
	private_gmsm_sm3_hasher_t *this;

	if (algo != HASH_SM3)
	{
		return NULL;
	}

	INIT(this,
		.public = {
			.hasher = {
				.reset = _reset,
				.get_hash = _get_hash,
				.allocate_hash = _allocate_hash,
				.get_hash_size = _get_hash_size,
				.destroy = _destroy,
			},
		},
	);

	/* Initialize SM3 context */
	sm3_init(&this->ctx);

	return &this->public;
}
