#!/bin/bash
# 创建 gmsm 插件的 Makefile.am

cd /tmp/strongswan-gmsm-final2/strongswan-5.9.6/src/libstrongswan/plugins/gmsm

cat > Makefile.am << 'EOF'
AM_CPPFLAGS = -I$(top_srcdir)/src/libstrongswan -I/usr/local/include

AM_CFLAGS = $(PLUGIN_CFLAGS)

if MONOLITHIC
noinst_LTLIBRARIES = libstrongswan-gmsm.la
else
plugin_LTLIBRARIES = libstrongswan-gmsm.la
endif

libstrongswan_gmsm_la_SOURCES = gmsm_plugin.h gmsm_plugin.c gmsm_sm3_hasher.h gmsm_sm3_hasher.c gmsm_sm4_crypter.h gmsm_sm4_crypter.c gmsm_sm2_public_key.h gmsm_sm2_public_key.c gmsm_sm2_private_key.h gmsm_sm2_private_key.c

libstrongswan_gmsm_la_LDFLAGS = -module -avoid-version -L/usr/local/lib

libstrongswan_gmsm_la_LIBADD = -lgmssl
EOF

echo "=== Created Makefile.am ==="
cat Makefile.am
