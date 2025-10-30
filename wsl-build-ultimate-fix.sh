#!/bin/bash
set -e

echo "========================================"
echo " strongSwan 5.9.6 + gmsm 插件编译脚本"
echo " 终极修复版 - 正确的ENUM顺序"
echo "========================================"

BUILD_DIR="/tmp/strongswan-gmsm-final2"
STRONGSWAN_VERSION="5.9.6"
WORK_DIR="$BUILD_DIR/strongswan-$STRONGSWAN_VERSION"
OUTPUT_DIR="/mnt/c/Code/strongswan/build-output"

echo ""
echo "步骤 1: 清理旧的构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo ""
echo "步骤 2: 下载 strongSwan 官方源码..."
if [ ! -f "strongswan-${STRONGSWAN_VERSION}.tar.gz" ]; then
    wget -q --show-progress https://download.strongswan.org/strongswan-${STRONGSWAN_VERSION}.tar.gz
fi
tar -xzf strongswan-${STRONGSWAN_VERSION}.tar.gz
cd "$WORK_DIR"

echo ""
echo "步骤 3: 复制 gmsm 插件源码..."
GMSM_SRC="/mnt/c/Code/strongswan/src/libstrongswan/plugins/gmsm"
GMSM_DST="src/libstrongswan/plugins/gmsm"
mkdir -p "$GMSM_DST"
cp -r "$GMSM_SRC"/* "$GMSM_DST/"
echo "✓ gmsm 插件已复制"

echo ""
echo "步骤 4: 应用头文件补丁..."

# hasher.h - 添加 SM3
sed -i 's/HASH_SHA3_512\([ \t]*=[ \t]*1032\)$/HASH_SHA3_512\1,/' src/libstrongswan/crypto/hashers/hasher.h
sed -i '/HASH_SHA3_512.*1032,/a\	/** Chinese SM3 */\n\tHASH_SM3 = 1033,' src/libstrongswan/crypto/hashers/hasher.h
sed -i '/^enum hash_algorithm_t {/,/^};/s/};/	\/** SM3 hash size in bytes *\/\n#define HASH_SIZE_SM3 32\n\n};/' src/libstrongswan/crypto/hashers/hasher.h
echo "  ✓ hasher.h 已添加 SM3 定义"

# crypter.h - 添加 SM4
sed -i 's/ENCR_CHACHA20_POLY1305\([ \t]*=[ \t]*1024\)$/ENCR_CHACHA20_POLY1305\1,/' src/libstrongswan/crypto/crypters/crypter.h
sed -i '/ENCR_CHACHA20_POLY1305.*1024,/a\	/** Chinese SM4 in CBC mode */\n\tENCR_SM4_CBC = 1025,\n\	/** Chinese SM4 in GCM mode with 16 octet ICV */\n\tENCR_SM4_GCM_ICV16 = 1026,' src/libstrongswan/crypto/crypters/crypter.h
sed -i '/^enum encryption_algorithm_t {/,/^};/s/};/	\/** SM4 block size in bytes *\/\n#define SM4_BLOCK_SIZE 16\n\n};/' src/libstrongswan/crypto/crypters/crypter.h
echo "  ✓ crypter.h 已添加 SM4 定义"

# public_key.h - 添加 SM2 密钥类型
sed -i 's/KEY_ED448\([ \t]*=[ \t]*5\)$/KEY_ED448\1,/' src/libstrongswan/credentials/keys/public_key.h
sed -i '/KEY_ED448.*5,/a\	/** Chinese SM2 elliptic curve */\n\tKEY_SM2 = 6,' src/libstrongswan/credentials/keys/public_key.h
echo "  ✓ public_key.h 已添加 SM2 密钥类型"

# public_key.h - 添加 SM2 签名方案
sed -i 's/\(SIGN_ED448\)$/\1,/' src/libstrongswan/credentials/keys/public_key.h
sed -i '/SIGN_ED448,/a\	/** SM2 signature with SM3 hash */\n\tSIGN_SM2_WITH_SM3,' src/libstrongswan/credentials/keys/public_key.h
echo "  ✓ public_key.h 已添加 SIGN_SM2_WITH_SM3"

echo ""
echo "步骤 5: 修改 public_key.c - 在正确位置插入 SM2 签名名称..."
# 在 "ED448" 之后插入 "SM2_WITH_SM3"
sed -i '/"ED448",/a\	"SM2_WITH_SM3",' src/libstrongswan/credentials/keys/public_key.c
echo "✓ public_key.c 已修改"

echo ""
echo "步骤 6: 修改 configure.ac..."
# 在 openssl 插件之后添加 gmsm 插件
sed -i '/ARG_ENABL_SET(\[openssl\])/a ARG_ENABL_SET([gmsm])' configure.ac

# 在 ADD_PLUGIN openssl 之后添加 gmsm
sed -i "/ADD_PLUGIN(\[openssl\],/a ADD_PLUGIN([gmsm], [s charon pki scripts nm cmd])" configure.ac

# 在文件末尾添加 AM_CONDITIONAL
if ! grep -q "AM_CONDITIONAL(USE_GMSM" configure.ac; then
    echo "" >> configure.ac
    echo "# gmsm plugin" >> configure.ac
    echo "AM_CONDITIONAL(USE_GMSM, test x\$gmsm = xtrue)" >> configure.ac
fi
echo "✓ configure.ac 已修改"

echo ""
echo "步骤 7: 修改 src/libstrongswan/Makefile.am..."
# 在 USE_OPENSSL 之前添加 gmsm
sed -i '/if USE_OPENSSL/i\if USE_GMSM\n  SUBDIRS += plugins/gmsm\nendif\n' src/libstrongswan/Makefile.am
echo "✓ Makefile.am 已修改"

echo ""
echo "步骤 8: 检查 GmSSL..."
if [ -f /usr/local/lib/libgmssl.so.3 ] || [ -f /usr/local/lib/libgmssl.so ]; then
    GMSSL_SIZE=$(du -sh /usr/local/lib/libgmssl.so* 2>/dev/null | head -1 | cut -f1)
    echo "✓ GmSSL 已安装: $GMSSL_SIZE"
    sudo ldconfig
else
    echo "❌ 错误: GmSSL 未安装"
    exit 1
fi

echo ""
echo "步骤 9: 生成 configure 脚本..."
autoreconf -fi
if [ $? -ne 0 ]; then
    echo "❌ autoreconf 失败"
    exit 1
fi
echo "✓ autoreconf 完成"

echo ""
echo "步骤 10: 配置编译选项..."
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-gmsm \
    --enable-openssl \
    --enable-eap-identity \
    --enable-eap-md5 \
    --enable-eap-mschapv2 \
    --enable-eap-tls \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp

if [ $? -ne 0 ]; then
    echo "❌ configure 失败"
    exit 1
fi

echo ""
echo "步骤 11: 编译 strongSwan + gmsm 插件..."
make -j$(nproc) 2>&1 | tee make.log

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo ""
    echo "❌ 编译失败,查看错误:"
    tail -100 make.log
    exit 1
fi

echo ""
echo "步骤 12: 验证 gmsm 插件..."
PLUGIN_SO="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ -f "$PLUGIN_SO" ]; then
    PLUGIN_SIZE=$(du -h "$PLUGIN_SO" | cut -f1)
    echo "✓ gmsm 插件编译成功: $PLUGIN_SIZE"
    
    # 检查符号
    if nm -D "$PLUGIN_SO" | grep -q gmsm_plugin_create; then
        echo "✓ 插件包含 gmsm_plugin_create 符号"
    fi
    
    # 检查依赖
    if ldd "$PLUGIN_SO" | grep -q libgmssl; then
        echo "✓ 插件链接到 libgmssl"
    fi
else
    echo "❌ 错误: 插件文件不存在"
    exit 1
fi

echo ""
echo "步骤 13: 复制插件到输出目录..."
mkdir -p "$OUTPUT_DIR"
cp "$PLUGIN_SO" "$OUTPUT_DIR/"
echo "✓ 插件已复制到: $OUTPUT_DIR/libstrongswan-gmsm.so"

echo ""
echo "========================================"
echo "✅ 编译成功完成!"
echo "========================================"
echo ""
echo "输出文件:"
echo "  - $OUTPUT_DIR/libstrongswan-gmsm.so"
echo ""
echo "下一步:"
echo "  1. 部署插件到云服务器"
echo "  2. 切换到 swanctl-gmssl.conf 配置"
echo "  3. 测试国密算法 VPN 连接"
echo ""
