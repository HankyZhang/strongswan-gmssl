AM_CPPFLAGS = \
	-I$(top_srcdir)/src/libstrongswan \
	-I/usr/local/include/gmssl

AM_CFLAGS = \
	$(PLUGIN_CFLAGS)

if MONOLITHIC
noinst_LTLIBRARIES = libstrongswan-gmsm.la
else
plugin_LTLIBRARIES = libstrongswan-gmsm.la
endif

libstrongswan_gmsm_la_SOURCES = \
	gmsm_plugin.h gmsm_plugin.c \
	gmsm_sm3_hasher.h gmsm_sm3_hasher.c \
	gmsm_sm3_signer.h gmsm_sm3_signer.c \
	gmsm_sm3_prf.h gmsm_sm3_prf.c \
	gmsm_sm4_crypter.h gmsm_sm4_crypter.c \
	gmsm_sm4_gcm_aead.h gmsm_sm4_gcm_aead.c \
	gmsm_sm2_private_key.h gmsm_sm2_private_key.c \
	gmsm_sm2_public_key.h gmsm_sm2_public_key.c \
	gmsm_sm2_dh.h gmsm_sm2_dh.c

libstrongswan_gmsm_la_LDFLAGS = -module -avoid-version
libstrongswan_gmsm_la_LIBADD = -lgmssl
