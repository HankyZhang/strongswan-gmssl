#!/bin/bash
#
# 绕过 autotools 直接编译 gmsm 插件
# 
# 原因: autogen.sh 有问题,但我们已经有了工作的 configure 脚本
# 策略: 直接在 plugins/gmsm 目录中手动编译,然后复制到正确位置
#

set -e

BUILD_DIR="/tmp/strongswan-gmsm-final2/strongswan-5.9.6"
GMSM_DIR="$BUILD_DIR/src/libstrongswan/plugins/gmsm"

cd "$BUILD_DIR"

echo "================================================"
echo "  手动编译 gmsm 插件"
echo "================================================"

echo ""
echo "[1/5] 编译 gmsm 插件对象文件..."
cd "$GMSM_DIR"

# 获取编译标志
CFLAGS="-g -O2 -fPIC -include $BUILD_DIR/config.h"
INCLUDES="-I$BUILD_DIR -I$BUILD_DIR/src/libstrongswan -I/usr/local/include/gmssl"

# 编译所有 .c 文件
for src in gmsm_plugin.c gmsm_sm3_hasher.c gmsm_sm4_crypter.c gmsm_sm2_public_key.c gmsm_sm2_private_key.c; do
    echo "  编译 $src ..."
    gcc $CFLAGS $INCLUDES -c "$src" -o "${src%.c}.o"
done

echo ""
echo "[2/5] 创建共享库..."
mkdir -p .libs

gcc -shared -fPIC \
    -o .libs/libstrongswan-gmsm.so.0.0.0 \
    gmsm_plugin.o \
    gmsm_sm3_hasher.o \
    gmsm_sm4_crypter.o \
    gmsm_sm2_public_key.o \
    gmsm_sm2_private_key.o \
    -L/usr/local/lib -lgmssl \
    -Wl,-soname -Wl,libstrongswan-gmsm.so.0

echo ""
echo "[3/5] 创建符号链接..."
cd .libs
ln -sf libstrongswan-gmsm.so.0.0.0 libstrongswan-gmsm.so.0
ln -sf libstrongswan-gmsm.so.0.0.0 libstrongswan-gmsm.so

echo ""
echo "[4/5] 验证编译结果..."
if [ -f "libstrongswan-gmsm.so" ]; then
    echo "✅ gmsm 插件编译成功!"
    echo ""
    ls -lh libstrongswan-gmsm.so*
    echo ""
    echo "插件符号:"
    nm -D libstrongswan-gmsm.so | grep 'plugin\|sm2\|sm3\|sm4' | head -15
    echo ""
    echo "链接库:"
    ldd libstrongswan-gmsm.so | grep gmssl
else
    echo "❌ 编译失败!"
    exit 1
fi

echo ""
echo "[5/5] 安装插件..."
echo "运行以下命令安装:"
echo "  sudo mkdir -p /usr/lib/ipsec/plugins/"
echo "  sudo cp .libs/libstrongswan-gmsm.so.* /usr/lib/ipsec/plugins/"
echo "  sudo ldconfig"

echo ""
echo "================================================"
echo "  编译完成!"
echo "================================================"
echo ""
echo "插件位置: $GMSM_DIR/.libs/libstrongswan-gmsm.so"
echo ""
echo "下一步:"
echo "  1. 安装插件 (sudo make install 或手动复制)"
echo "  2. 配置 strongswan.conf 启用 gmsm"
echo "  3. 测试插件功能"
