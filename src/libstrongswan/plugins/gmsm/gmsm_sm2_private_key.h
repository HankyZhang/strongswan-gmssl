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

/**
 * @defgroup gmsm_sm2_private_key gmsm_sm2_private_key
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM2_PRIVATE_KEY_H_
#define GMSM_SM2_PRIVATE_KEY_H_

#include <credentials/builder.h>
#include <credentials/keys/private_key.h>

typedef struct gmsm_sm2_private_key_t gmsm_sm2_private_key_t;

/**
 * SM2 private key implementation using GmSSL library
 */
struct gmsm_sm2_private_key_t {

	/**
	 * Implements private_key_t interface
	 */
	private_key_t key;
};

/**
 * Generate a SM2 private key
 * 
 * @param type		must be KEY_SM2
 * @param args		builder_part_t argument list
 * @return			generated key, NULL on failure
 */
gmsm_sm2_private_key_t *gmsm_sm2_private_key_gen(key_type_t type, va_list args);

/**
 * Load a SM2 private key
 * 
 * @param type		must be KEY_SM2
 * @param args		builder_part_t argument list
 * @return			loaded key, NULL on failure
 */
gmsm_sm2_private_key_t *gmsm_sm2_private_key_load(key_type_t type, va_list args);

#endif /** GMSM_SM2_PRIVATE_KEY_H_ @}*/
