/*
 * Copyright (C) 2025 HankyZhang
 * 
 * SM3 PRF implementation using GmSSL
 */

/**
 * @defgroup gmsm_sm3_prf gmsm_sm3_prf
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM3_PRF_H_
#define GMSM_SM3_PRF_H_

typedef struct gmsm_sm3_prf_t gmsm_sm3_prf_t;

#include <crypto/prfs/prf.h>

/**
 * Implementation of prf_t using HMAC-SM3
 */
struct gmsm_sm3_prf_t {

	/**
	 * Implements prf_t interface
	 */
	prf_t prf;
};

/**
 * Creates a new gmsm_sm3_prf_t
 *
 * @param algo		algorithm to use (must be PRF_HMAC_SM3)
 * @return			gmsm_sm3_prf_t object, NULL if not supported
 */
prf_t *gmsm_sm3_prf_create(pseudo_random_function_t algo);

#endif /** GMSM_SM3_PRF_H_ @}*/
