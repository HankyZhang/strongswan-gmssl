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

/**
 * @defgroup gmsm_sm4_crypter gmsm_sm4_crypter
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM4_CRYPTER_H_
#define GMSM_SM4_CRYPTER_H_

#include <crypto/crypters/crypter.h>

typedef struct gmsm_sm4_crypter_t gmsm_sm4_crypter_t;

/**
 * SM4 crypter implementation using GmSSL library
 */
struct gmsm_sm4_crypter_t {

	/**
	 * Implements crypter_t interface
	 */
	crypter_t crypter;
};

/**
 * Create a SM4 crypter
 * 
 * @param algo		encryption algorithm (ENCR_SM4_CBC or ENCR_SM4_GCM)
 * @param key_size	key size in bytes (must be 16)
 * @return			gmsm_sm4_crypter_t, NULL if not supported
 */
gmsm_sm4_crypter_t *gmsm_sm4_crypter_create(encryption_algorithm_t algo, 
											size_t key_size);

#endif /** GMSM_SM4_CRYPTER_H_ @}*/
