#!/bin/bash
# 彻底解决方案: 使用官方源码 + 补丁方式集成 gmsm 插件

set -e

echo "=========================================="
echo "strongSwan + gmsm 插件编译 (完整方案)"
echo "=========================================="

# 工作目录
WORK_DIR="/tmp/strongswan-gmsm-build"
PATCH_DIR="/mnt/c/Code/strongswan"

echo "步骤 1: 清理并创建工作目录..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 下载官方 strongSwan 源码
echo ""
echo "步骤 2: 下载 strongSwan 5.9.6 官方源码..."
wget -q --show-progress https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6
echo "✓ 官方源码下载完成"

# 复制 gmsm 插件源码
echo ""
echo "步骤 3: 复制 gmsm 插件源码..."
mkdir -p src/libstrongswan/plugins/gmsm
cp "$PATCH_DIR/src/libstrongswan/plugins/gmsm/"* src/libstrongswan/plugins/gmsm/
echo "✓ gmsm 插件源码已复制"
ls -lh src/libstrongswan/plugins/gmsm/*.c | awk '{print "  -", $9, "("$5")"}'

# 复制修改过的头文件
echo ""
echo "步骤 4: 应用头文件补丁..."
cp "$PATCH_DIR/src/libstrongswan/crypto/hashers/hasher.h" src/libstrongswan/crypto/hashers/
cp "$PATCH_DIR/src/libstrongswan/crypto/crypters/crypter.h" src/libstrongswan/crypto/crypters/
cp "$PATCH_DIR/src/libstrongswan/credentials/keys/public_key.h" src/libstrongswan/credentials/keys/
echo "✓ 头文件补丁已应用"

# 修改 configure.ac
echo ""
echo "步骤 5: 修改 configure.ac..."
# 添加 gmsm 插件配置
sed -i '/ARG_ENABL_SET(\[openssl\])/a ARG_ENABL_SET([gmsm])' configure.ac
sed -i '/ADD_PLUGIN(\[openssl\]/a ADD_PLUGIN([gmsm], [s charon pki scripts nm cmd])' configure.ac
# 在文件末尾添加 AM_CONDITIONAL
echo 'AM_CONDITIONAL(USE_GMSM, test x$gmsm = xtrue)' >> configure.ac
echo "✓ configure.ac 已修改"

# 修改 src/libstrongswan/Makefile.am
echo ""
echo "步骤 6: 修改 src/libstrongswan/Makefile.am..."
# 在 SUBDIRS 中添加 gmsm
sed -i '/if USE_OPENSSL/i if USE_GMSM\n  SUBDIRS += plugins/gmsm\nendif\n' src/libstrongswan/Makefile.am
echo "✓ Makefile.am 已修改"

# 检查 GmSSL
echo ""
echo "步骤 7: 检查 GmSSL..."
if [ ! -f "/usr/local/lib/libgmssl.so.3.1" ]; then
    echo "❌ 错误: GmSSL 未安装"
    exit 1
fi
echo "✓ GmSSL 已安装: $(ls -lh /usr/local/lib/libgmssl.so.3.1 | awk '{print $5}')"
sudo ldconfig

# 生成 configure
echo ""
echo "步骤 8: 生成 configure 脚本..."
autoreconf -fi
echo "✓ configure 生成完成"

# 配置
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

# 编译
echo ""
echo "步骤 10: 编译 strongSwan + gmsm 插件..."
make -j$(nproc)
echo "✓ 编译完成"

# 验证插件
echo ""
echo "步骤 11: 验证 gmsm 插件..."
PLUGIN_PATH="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ ! -f "$PLUGIN_PATH" ]; then
    echo "❌ 错误: 插件未生成"
    echo "查看可能的位置:"
    find . -name "*gmsm*.so" 2>/dev/null
    exit 1
fi

echo "✓ 插件生成成功:"
ls -lh "$PLUGIN_PATH"

echo ""
echo "检查插件符号:"
nm -D "$PLUGIN_PATH" | grep -E "gmsm_plugin_create" || echo "  未找到 gmsm_plugin_create"

echo ""
echo "检查插件依赖:"
ldd "$PLUGIN_PATH" | grep -E "libgmssl|libc"

# 复制到 Windows
echo ""
echo "步骤 12: 复制插件到 Windows 文件系统..."
mkdir -p "$PATCH_DIR/build-output"
cp "$PLUGIN_PATH" "$PATCH_DIR/build-output/libstrongswan-gmsm.so"
echo "✓ 插件已复制"

echo ""
echo "=========================================="
echo "✅ 编译成功完成!"
echo "=========================================="
echo ""
echo "编译产物:"
echo "  - 插件: $PATCH_DIR/build-output/libstrongswan-gmsm.so"
echo "  - 大小: $(ls -lh $PATCH_DIR/build-output/libstrongswan-gmsm.so | awk '{print $5}')"
echo ""
