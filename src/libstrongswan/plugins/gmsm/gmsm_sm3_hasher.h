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

/**
 * @defgroup gmsm_sm3_hasher gmsm_sm3_hasher
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM3_HASHER_H_
#define GMSM_SM3_HASHER_H_

#include <crypto/hashers/hasher.h>

typedef struct gmsm_sm3_hasher_t gmsm_sm3_hasher_t;

/**
 * SM3 hasher implementation using GmSSL library
 */
struct gmsm_sm3_hasher_t {

	/**
	 * Implements hasher_t interface
	 */
	hasher_t hasher;
};

/**
 * Create a SM3 hasher
 * 
 * @param algo		must be HASH_SM3
 * @return			gmsm_sm3_hasher_t, NULL if not supported
 */
gmsm_sm3_hasher_t *gmsm_sm3_hasher_create(hash_algorithm_t algo);

#endif /** GMSM_SM3_HASHER_H_ @}*/
