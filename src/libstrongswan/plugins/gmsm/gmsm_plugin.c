/*
 * Copyright (C) 2025 HankyZhang
 * 
 * GmSSL plugin for Chinese SM2/SM3/SM4 algorithms
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 */

#include "gmsm_plugin.h"

#ifndef VERSION
#define VERSION "6.0.3dr1"
#endif
#include "gmsm_sm3_hasher.h"
#include "gmsm_sm4_crypter.h"
#include "gmsm_sm4_gcm_aead.h"
#include "gmsm_sm2_private_key.h"
#include "gmsm_sm2_public_key.h"
#include "gmsm_sm3_signer.h"
#include "gmsm_sm3_prf.h"
#include "gmsm_sm2_dh.h"

#include <library.h>

typedef struct private_gmsm_plugin_t private_gmsm_plugin_t;

/**
 * Private data of gmsm_plugin
 */
struct private_gmsm_plugin_t {

	/**
	 * public functions
	 */
	gmsm_plugin_t public;
};

METHOD(plugin_t, get_name, char*,
	private_gmsm_plugin_t *this)
{
	return "gmsm";
}

METHOD(plugin_t, get_features, int,
	private_gmsm_plugin_t *this, plugin_feature_t *features[])
{
	static plugin_feature_t f[] = {
		/* SM3 hasher */
		PLUGIN_REGISTER(HASHER, gmsm_sm3_hasher_create),
			PLUGIN_PROVIDE(HASHER, HASH_SM3),
		/* SM3 HMAC signer */
		PLUGIN_REGISTER(SIGNER, gmsm_sm3_signer_create),
			PLUGIN_PROVIDE(SIGNER, AUTH_HMAC_SM3_96),
		/* SM3 PRF */
		PLUGIN_REGISTER(PRF, gmsm_sm3_prf_create),
			PLUGIN_PROVIDE(PRF, PRF_HMAC_SM3),
		/* SM4 crypter */
		PLUGIN_REGISTER(CRYPTER, gmsm_sm4_crypter_create),
			PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CBC, 16),
		/* SM4 GCM AEAD */
		PLUGIN_REGISTER(AEAD, gmsm_sm4_gcm_aead_create),
			PLUGIN_PROVIDE(AEAD, ENCR_SM4_GCM_ICV16, 16),
				PLUGIN_DEPENDS(CRYPTER, ENCR_SM4_CBC, 16),
		/* SM2 Diffie-Hellman */
		PLUGIN_REGISTER(KE, gmsm_sm2_dh_create),
			PLUGIN_PROVIDE(KE, SM2_256),
				PLUGIN_DEPENDS(RNG, RNG_STRONG),
		/* SM2 key registration re-enabled for debug */
		#define ENABLE_SM2_KEYS 1
		#ifdef ENABLE_SM2_KEYS
		PLUGIN_REGISTER(PRIVKEY, gmsm_sm2_private_key_load, TRUE),
			PLUGIN_PROVIDE(PRIVKEY, KEY_SM2),
			PLUGIN_PROVIDE(PRIVKEY, KEY_ANY),
				PLUGIN_PROVIDE(PRIVKEY_SIGN, SIGN_SM2_WITH_SM3),
		PLUGIN_REGISTER(PRIVKEY_GEN, gmsm_sm2_private_key_gen, FALSE),
			PLUGIN_PROVIDE(PRIVKEY_GEN, KEY_SM2),
		PLUGIN_REGISTER(PUBKEY, gmsm_sm2_public_key_load, TRUE),
			PLUGIN_PROVIDE(PUBKEY, KEY_SM2),
			PLUGIN_PROVIDE(PUBKEY, KEY_ANY),
				PLUGIN_PROVIDE(PUBKEY_VERIFY, SIGN_SM2_WITH_SM3),
#endif
	};
	*features = f;
	return countof(f);
}

METHOD(plugin_t, destroy, void,
	private_gmsm_plugin_t *this)
{
	free(this);
}

/*
 * Described in header
 */
PLUGIN_DEFINE(gmsm)
{
	private_gmsm_plugin_t *this;

	INIT(this,
		.public = {
			.plugin = {
				.get_name = _get_name,
				.get_features = _get_features,
				.destroy = _destroy,
			},
		},
	);

	return &this->public.plugin;
}
