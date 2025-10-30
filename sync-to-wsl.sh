#!/bin/bash
#
# 同步所有 Windows 修改到 WSL 构建目录
# 包括头文件中的 enum 定义和 gmsm 插件源代码
#

set -e

WIN_SRC="/mnt/c/Code/strongswan"
BUILD_DIR="/tmp/strongswan-gmsm-final2/strongswan-5.9.6"

echo "================================================"
echo "  同步源代码到 WSL 构建目录"
echo "================================================"

echo ""
echo "[1/4] 同步修改过的头文件 (enum 定义)..."

# crypters/crypter.h - SM4 算法定义
echo "  - crypters/crypter.h (SM4_CBC, SM4_GCM)"
cp "$WIN_SRC/src/libstrongswan/crypto/crypters/crypter.h" \
   "$BUILD_DIR/src/libstrongswan/crypto/crypters/"
cp "$WIN_SRC/src/libstrongswan/crypto/crypters/crypter.c" \
   "$BUILD_DIR/src/libstrongswan/crypto/crypters/"

# hashers/hasher.h - SM3 算法定义
echo "  - hashers/hasher.h (SM3)"
cp "$WIN_SRC/src/libstrongswan/crypto/hashers/hasher.h" \
   "$BUILD_DIR/src/libstrongswan/crypto/hashers/"
cp "$WIN_SRC/src/libstrongswan/crypto/hashers/hasher.c" \
   "$BUILD_DIR/src/libstrongswan/crypto/hashers/"

# keys/public_key.h - SM2 算法定义
echo "  - credentials/keys/public_key.h (SM2, SIGN_SM2_WITH_SM3)"
cp "$WIN_SRC/src/libstrongswan/credentials/keys/public_key.h" \
   "$BUILD_DIR/src/libstrongswan/credentials/keys/"
cp "$WIN_SRC/src/libstrongswan/credentials/keys/public_key.c" \
   "$BUILD_DIR/src/libstrongswan/credentials/keys/"

echo ""
echo "[2/4] 同步 gmsm 插件源代码..."
echo "  - plugins/gmsm/*.c"
echo "  - plugins/gmsm/*.h"
cp "$WIN_SRC/src/libstrongswan/plugins/gmsm/"*.c \
   "$BUILD_DIR/src/libstrongswan/plugins/gmsm/" 2>/dev/null || true
cp "$WIN_SRC/src/libstrongswan/plugins/gmsm/"*.h \
   "$BUILD_DIR/src/libstrongswan/plugins/gmsm/" 2>/dev/null || true

echo ""
echo "[3/4] 验证同步结果..."

# 检查 SM4 定义
if grep -q "ENCR_SM4_CBC" "$BUILD_DIR/src/libstrongswan/crypto/crypters/crypter.h"; then
    echo "  ✅ SM4 算法已同步"
else
    echo "  ❌ SM4 算法同步失败"
    exit 1
fi

# 检查 SM3 定义  
if grep -q "HASH_SM3" "$BUILD_DIR/src/libstrongswan/crypto/hashers/hasher.h"; then
    echo "  ✅ SM3 算法已同步"
else
    echo "  ❌ SM3 算法同步失败"
    exit 1
fi

# 检查 SM2 定义
if grep -q "KEY_SM2" "$BUILD_DIR/src/libstrongswan/credentials/keys/public_key.h"; then
    echo "  ✅ SM2 算法已同步"
else
    echo "  ❌ SM2 算法同步失败"
    exit 1
fi

# 检查 gmsm 插件源文件
if [ -f "$BUILD_DIR/src/libstrongswan/plugins/gmsm/gmsm_plugin.c" ]; then
    echo "  ✅ gmsm 插件源代码已同步"
else
    echo "  ❌ gmsm 插件源代码同步失败"
    exit 1
fi

echo ""
echo "[4/4] 列出所有修改的文件..."
echo ""
echo "crypters/crypter.h:"
grep -n "ENCR_SM4" "$BUILD_DIR/src/libstrongswan/crypto/crypters/crypter.h" | head -5

echo ""
echo "hashers/hasher.h:"
grep -n "HASH_SM3" "$BUILD_DIR/src/libstrongswan/crypto/hashers/hasher.h" | head -5

echo ""
echo "credentials/keys/public_key.h:"
grep -n "KEY_SM2\|SIGN_SM2" "$BUILD_DIR/src/libstrongswan/credentials/keys/public_key.h" | head -5

echo ""
echo "================================================"
echo "  同步完成!"
echo "================================================"
echo ""
echo "下一步: 运行 compile-gmsm-manual.sh 编译插件"
