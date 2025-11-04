#!/usr/bin/env bash
set -euo pipefail

SRC_WIN="/mnt/c/Code/strongswan"
WSL_COPY="$HOME/strongswan-gmsm"
PREFIX="/usr"
CONF_OPTS="--prefix=${PREFIX} --sysconfdir=/etc --enable-gmsm --enable-openssl --enable-swanctl --enable-vici --disable-gmp --with-systemdsystemunitdir=no"

echo "[1/7] Sync source -> $WSL_COPY"
mkdir -p "$WSL_COPY"
rsync -a --delete "$SRC_WIN/" "$WSL_COPY/"

cd "$WSL_COPY"
chmod +x scripts/git-version || true

echo "[2/7] Autotools regenerate"
autoreconf -i

echo "[3/7] Configure ($CONF_OPTS)"
./configure $CONF_OPTS || { echo 'Configure failed'; exit 1; }

echo "[4/7] Build (make -j$(nproc))"
make -j"$(nproc)"

PLUGIN_SO="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ -f "$PLUGIN_SO" ]; then
  echo "[5/7] Plugin built: $PLUGIN_SO"
else
  echo "[5/7] Plugin not found; build may have failed"; exit 1
fi

echo "[6/7] Copy artifact back to Windows tree"
cp "$PLUGIN_SO" "$SRC_WIN/libstrongswan-gmsm.so" || echo 'Copy back failed'

echo "[7/7] Summary"
ldd "$PLUGIN_SO" || true
strings "$PLUGIN_SO" | grep -E 'SM3|SM4|SM2' || true

echo 'Done.'
