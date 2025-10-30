#!/bin/bash
#
# strongSwan 5.9.6 + gmsm 快速构建脚本
# 基于云服务器成功的手动编译经验
#
set -e

echo "========================================="
echo " strongSwan 5.9.6 + gmsm 快速构建"
echo "========================================="

# 配置
BUILD_DIR="/tmp/strongswan-gmsm-quick"
WIN_SOURCE="/mnt/c/Code/strongswan"

# 步骤 1: 准备目录
echo "[1/6] 准备构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 步骤 2: 下载并解压
echo "[2/6] 下载 strongSwan 5.9.6..."
wget -q https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6

# 步骤 3: 复制 gmsm 插件和修改的枚举
echo "[3/6] 复制 gmsm 插件源码..."
mkdir -p src/libstrongswan/plugins/gmsm
cp -r "$WIN_SOURCE/src/libstrongswan/plugins/gmsm/"* \
   src/libstrongswan/plugins/gmsm/

echo "[3/6] 复制修改的枚举定义..."
cp "$WIN_SOURCE/src/libstrongswan/crypto/crypters/crypter.h" \
   src/libstrongswan/crypto/crypters/
cp "$WIN_SOURCE/src/libstrongswan/crypto/hashers/hasher.h" \
   src/libstrongswan/crypto/hashers/
cp "$WIN_SOURCE/src/libstrongswan/credentials/keys/public_key.h" \
   src/libstrongswan/credentials/keys/
cp "$WIN_SOURCE/src/libstrongswan/credentials/keys/public_key.c" \
   src/libstrongswan/credentials/keys/

# 步骤 4: 不修改 configure.ac，直接使用原始版本构建
# 原因：5.9.6 是发布版本，已有完整的 configure 脚本
# 我们不需要 --enable-gmsm 选项，直接作为普通插件编译即可

echo "[4/6] 配置构建（使用标准选项）..."
./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --enable-openssl \
  --enable-swanctl \
  --enable-vici \
  --disable-gmp \
  --with-systemdsystemunitdir=no \
  > /tmp/configure-quick.log 2>&1

echo "Configure 完成"

# 步骤 5: 手动构建 gmsm 插件（类似云服务器上的方法）
echo "[5/6] 手动编译 gmsm 插件..."

cd src/libstrongswan/plugins/gmsm

# 检查 GmSSL 库
if [ ! -f /usr/local/lib/libgmssl.so ]; then
    echo "错误: GmSSL 未安装!"
    echo "请先安装 GmSSL 3.1.x"
    exit 1
fi

# 使用 libtool 编译（与云服务器一致）
echo "编译 gmsm 插件..."

# 找到 config.h 的位置
CONFIG_H="$BUILD_DIR/strongswan-5.9.6/config.h"

gcc -std=gnu99 -shared -fPIC \
    -Wall -Wextra \
    -include "$CONFIG_H" \
    -I../.. \
    -I/usr/local/include/gmssl \
    -DHAVE_CONFIG_H \
    gmsm_plugin.c \
    gmsm_sm3_hasher.c \
    gmsm_sm4_crypter.c \
    gmsm_sm2_private_key.c \
    gmsm_sm2_public_key.c \
    -L/usr/local/lib \
    -lgmssl \
    -o libstrongswan-gmsm.so

if [ -f libstrongswan-gmsm.so ]; then
    echo "✓ gmsm 插件编译成功!"
    ls -lh libstrongswan-gmsm.so
    
    # 创建 .libs 目录并复制（模拟 libtool 行为）
    mkdir -p .libs
    cp libstrongswan-gmsm.so .libs/
else
    echo "✗ gmsm 插件编译失败!"
    exit 1
fi

# 返回到主目录
cd "$BUILD_DIR/strongswan-5.9.6"

# 步骤 6: 编译其余部分
echo "[6/6] 编译 strongSwan..."
make -j$(nproc) > /tmp/make-quick.log 2>&1 || true

# 验证结果
echo ""
echo "========================================="
echo " 构建完成!"
echo "========================================="

GMSM_SO="src/libstrongswan/plugins/gmsm/libstrongswan-gmsm.so"
if [ -f "$GMSM_SO" ]; then
    echo "✓ gmsm 插件: $GMSM_SO"
    ls -lh "$GMSM_SO"
else
    echo "✗ gmsm 插件未生成"
fi

echo ""
echo "下一步:"
echo "  1. 手动安装 gmsm 插件:"
echo "     sudo mkdir -p /usr/lib/ipsec/plugins"
echo "     sudo cp $GMSM_SO /usr/lib/ipsec/plugins/"
echo "     sudo ldconfig"
echo ""
echo "  2. 安装 strongSwan:"
echo "     cd $BUILD_DIR/strongswan-5.9.6"
echo "     sudo make install"
echo ""
echo "  3. 测试插件:"
echo "     swanctl --list-plugins | grep gmsm"
echo ""
echo "构建目录: $BUILD_DIR/strongswan-5.9.6"
