#!/bin/bash
# 最终修复版 - 正确处理枚举值和逗号

set -e

echo "=========================================="
echo "strongSwan + gmsm 插件编译 (最终修复版)"
echo "=========================================="

WORK_DIR="/tmp/strongswan-gmsm-success"
PATCH_DIR="/mnt/c/Code/strongswan"

echo "步骤 1: 准备工作目录..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo ""
echo "步骤 2: 下载 strongSwan 5.9.6 官方源码..."
wget -q --show-progress https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6
echo "✓ 官方源码下载完成"

echo ""
echo "步骤 3: 复制 gmsm 插件源码..."
mkdir -p src/libstrongswan/plugins/gmsm
cp "$PATCH_DIR/src/libstrongswan/plugins/gmsm/"*.c src/libstrongswan/plugins/gmsm/
cp "$PATCH_DIR/src/libstrongswan/plugins/gmsm/"*.h src/libstrongswan/plugins/gmsm/
cp "$PATCH_DIR/src/libstrongswan/plugins/gmsm/Makefile.am" src/libstrongswan/plugins/gmsm/
echo "✓ gmsm 插件源码已复制"

echo ""
echo "步骤 4: 应用头文件补丁..."

# 修改 hasher.h - 添加 SM3
if ! grep -q "HASH_SM3" src/libstrongswan/crypto/hashers/hasher.h; then
    # 先给 HASH_SHA3_512 添加逗号,然后添加 SM3
    sed -i 's/HASH_SHA3_512\([ \t]*=[ \t]*1032\)$/HASH_SHA3_512\1,/' src/libstrongswan/crypto/hashers/hasher.h
    # 在 HASH_SHA3_512 后添加 SM3
    sed -i '/HASH_SHA3_512.*1032,/a\	/** Chinese SM3 */\n\tHASH_SM3 = 1033,' src/libstrongswan/crypto/hashers/hasher.h
    # 在 HASH_SIZE_SHA3_512 后添加 SM3 size
    sed -i '/#define HASH_SIZE_SHA3_512/a #define HASH_SIZE_SM3 32' src/libstrongswan/crypto/hashers/hasher.h
    echo "  ✓ hasher.h 已添加 SM3 定义"
else
    echo "  - hasher.h 已包含 SM3"
fi

# 修改 crypter.h - 添加 SM4
if ! grep -q "ENCR_SM4_CBC" src/libstrongswan/crypto/crypters/crypter.h; then
    # 先给最后一个枚举添加逗号
    sed -i 's/ENCR_CHACHA20_POLY1305\([ \t]*=[ \t]*1024\)$/ENCR_CHACHA20_POLY1305\1,/' src/libstrongswan/crypto/crypters/crypter.h
    # 添加 SM4
    sed -i '/ENCR_CHACHA20_POLY1305.*1024,/a\	/** Chinese SM4 in CBC mode */\n\tENCR_SM4_CBC = 1025,\n\	/** Chinese SM4 in GCM mode with 16 octet ICV */\n\tENCR_SM4_GCM_ICV16 = 1026,' src/libstrongswan/crypto/crypters/crypter.h
    # 添加 SM4 block size
    sed -i '/#define ENCR_BLOCK_SIZE/i #define SM4_BLOCK_SIZE 16\n' src/libstrongswan/crypto/crypters/crypter.h
    echo "  ✓ crypter.h 已添加 SM4 定义"
else
    echo "  - crypter.h 已包含 SM4"
fi

# 修改 public_key.h - 添加 SM2
if ! grep -q "KEY_SM2" src/libstrongswan/credentials/keys/public_key.h; then
    # 先给 KEY_ED448 添加逗号
    sed -i 's/KEY_ED448\([ \t]*=[ \t]*5\)$/KEY_ED448\1,/' src/libstrongswan/credentials/keys/public_key.h
    # 添加 KEY_SM2
    sed -i '/KEY_ED448.*5,/a\	/** Chinese SM2 elliptic curve */\n\tKEY_SM2 = 6,' src/libstrongswan/credentials/keys/public_key.h
    # 给最后一个签名方案添加逗号
    sed -i 's/\(SIGN_ED448\)$/\1,/' src/libstrongswan/credentials/keys/public_key.h
    # 添加 SIGN_SM2_WITH_SM3
    sed -i '/SIGN_ED448,/a\	/** SM2 signature with SM3 hash */\n\tSIGN_SM2_WITH_SM3,' src/libstrongswan/credentials/keys/public_key.h
    echo "  ✓ public_key.h 已添加 SM2 定义"
else
    echo "  - public_key.h 已包含 SM2"
fi

echo ""
echo "步骤 5: 修改 configure.ac..."
sed -i '/ARG_ENABL_SET(\[openssl\])/a ARG_ENABL_SET([gmsm])' configure.ac
sed -i '/ADD_PLUGIN(\[openssl\]/a ADD_PLUGIN([gmsm], [s charon pki scripts nm cmd])' configure.ac
echo 'AM_CONDITIONAL(USE_GMSM, test x$gmsm = xtrue)' >> configure.ac
echo "✓ configure.ac 已修改"

echo ""
echo "步骤 6: 修改 src/libstrongswan/Makefile.am..."
sed -i '/if USE_OPENSSL/i if USE_GMSM\n  SUBDIRS += plugins/gmsm\nendif\n' src/libstrongswan/Makefile.am
echo "✓ Makefile.am 已修改"

echo ""
echo "步骤 7: 检查 GmSSL..."
if [ ! -f "/usr/local/lib/libgmssl.so.3.1" ]; then
    echo "❌ 错误: GmSSL 未安装"
    exit 1
fi
echo "✓ GmSSL 已安装: $(ls -lh /usr/local/lib/libgmssl.so.3.1 | awk '{print $5}')"
sudo ldconfig

echo ""
echo "步骤 8: 生成 configure 脚本..."
autoreconf -fi
echo "✓ configure 生成完成"

echo ""
echo "步骤 9: 配置编译选项..."
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export CFLAGS="-I/usr/local/include -std=gnu99"
export LDFLAGS="-L/usr/local/lib"

./configure \
    --prefix=/usr/local/strongswan \
    --enable-gmsm \
    --enable-openssl \
    --sysconfdir=/etc \
    --with-ipseclibdir=/usr/local/strongswan/lib/ipsec

echo "✓ 配置完成"

echo ""
echo "步骤 10: 编译 strongSwan + gmsm 插件..."
make -j$(nproc) 2>&1 | tee make.log
MAKE_STATUS=${PIPESTATUS[0]}

if [ $MAKE_STATUS -ne 0 ]; then
    echo ""
    echo "❌ 编译失败,查看错误:"
    tail -100 make.log
    exit 1
fi

echo "✓ 编译完成"

echo ""
echo "步骤 11: 验证 gmsm 插件..."
PLUGIN_PATH="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ ! -f "$PLUGIN_PATH" ]; then
    echo "❌ 错误: 插件未生成"
    find . -name "*gmsm*.so" 2>/dev/null
    exit 1
fi

echo "✓ 插件生成成功:"
ls -lh "$PLUGIN_PATH"

echo ""
echo "检查插件符号:"
nm -D "$PLUGIN_PATH" | grep -E "gmsm_plugin_create" | head -5 || true

echo ""
echo "检查插件依赖:"
ldd "$PLUGIN_PATH" | grep -E "libgmssl|libc"

echo ""
echo "步骤 12: 复制到 Windows..."
mkdir -p "$PATCH_DIR/build-output"
cp "$PLUGIN_PATH" "$PATCH_DIR/build-output/libstrongswan-gmsm.so"
echo "✓ 插件已复制"

echo ""
echo "=========================================="
echo "✅ 编译成功完成!"
echo "=========================================="
echo ""
echo "编译产物:"
ls -lh "$PATCH_DIR/build-output/libstrongswan-gmsm.so"
echo ""
