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
#include "gmsm_sm3_hasher.h"

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
plugin_t *gmsm_plugin_create()
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
