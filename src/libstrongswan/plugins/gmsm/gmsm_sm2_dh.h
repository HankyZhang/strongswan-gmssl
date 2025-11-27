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

/**
 * @defgroup gmsm_sm2_dh gmsm_sm2_dh
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM2_DH_H_
#define GMSM_SM2_DH_H_

typedef struct gmsm_sm2_dh_t gmsm_sm2_dh_t;

#include <library.h>
#include <crypto/key_exchange.h>

/**
 * Implementation of the SM2-based Diffie-Hellman key exchange.
 */
struct gmsm_sm2_dh_t {

	/**
	 * Implements key_exchange_t interface.
	 */
	key_exchange_t ke;
};

/**
 * Creates a new gmsm_sm2_dh_t object for SM2 key exchange.
 *
 * @param group			Key exchange method (should be SM2_256)
 * @param ...			expects generator and prime as chunk_t if MODP
 * @return				gmsm_sm2_dh_t object, NULL if not supported
 */
gmsm_sm2_dh_t *gmsm_sm2_dh_create(key_exchange_method_t group, ...);

#endif /** GMSM_SM2_DH_H_ @}*/
