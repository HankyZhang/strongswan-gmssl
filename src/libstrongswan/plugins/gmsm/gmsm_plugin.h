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

/**
 * @defgroup gmsm_p gmsm
 * @ingroup plugins
 *
 * @defgroup gmsm_plugin gmsm_plugin
 * @{ @ingroup gmsm_p
 */

#ifndef GMSM_PLUGIN_H_
#define GMSM_PLUGIN_H_

#include <plugins/plugin.h>

typedef struct gmsm_plugin_t gmsm_plugin_t;

/**
 * Plugin implementing Chinese SM2/SM3/SM4 algorithms using GmSSL library
 */
struct gmsm_plugin_t {

	/**
	 * implements plugin interface
	 */
	plugin_t plugin;
};

#endif /** GMSM_PLUGIN_H_ @}*/
