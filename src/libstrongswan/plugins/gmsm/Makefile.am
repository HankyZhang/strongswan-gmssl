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
	gmsm_sm3_hasher.h gmsm_sm3_hasher.c

libstrongswan_gmsm_la_LDFLAGS = -module -avoid-version
libstrongswan_gmsm_la_LIBADD = -lgmssl
