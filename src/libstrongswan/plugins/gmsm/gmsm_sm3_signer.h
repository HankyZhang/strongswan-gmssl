/*
 * Copyright (C) 2025 HankyZhang
 * 
 * HMAC-SM3 signer implementation using GmSSL
 */

/**
 * @defgroup gmsm_sm3_signer gmsm_sm3_signer
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_SM3_SIGNER_H_
#define GMSM_SM3_SIGNER_H_

typedef struct gmsm_sm3_signer_t gmsm_sm3_signer_t;

#include <crypto/signers/signer.h>

/**
 * Implementation of signer_t using HMAC-SM3
 */
struct gmsm_sm3_signer_t {

	/**
	 * Implements signer_t interface
	 */
	signer_t signer;
};

/**
 * Creates a new gmsm_sm3_signer_t
 *
 * @param algo		algorithm to use (must be AUTH_HMAC_SM3_96)
 * @return			gmsm_sm3_signer_t object, NULL if not supported
 */
signer_t *gmsm_sm3_signer_create(integrity_algorithm_t algo);

#endif /** GMSM_SM3_SIGNER_H_ @}*/
