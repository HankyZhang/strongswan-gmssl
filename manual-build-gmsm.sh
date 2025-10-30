#!/bin/bash
#
# 手动编译 strongSwan gmsm 插件
# 适用于无法运行 autogen.sh 的环境
#

set -e

echo "=== 手动编译 gmsm 插件 ==="

# 1. 编译主 strongSwan (不启用 gmsm)
echo "[1/4] 编译 strongSwan 主体..."
cd ~/strongswan-gmssl

# 使用简化的 configure (从源码包获取)
if [ ! -f Makefile ]; then
    wget https://download.strongswan.org/strongswan-5.9.6.tar.gz
    tar -zxf strongswan-5.9.6.tar.gz
    cd strongswan-5.9.6
    ./configure --prefix=/usr/local/strongswan \
        --sysconfdir=/etc \
        --enable-openssl \
        --enable-swanctl \
        --enable-vici \
        --disable-gmp
    make -j2
    make install
    ldconfig
    cd ~/strongswan-gmssl
fi

# 2. 编译 libstrongswan 库
echo "[2/4] 确保 libstrongswan 已安装..."
if [ ! -f /usr/local/strongswan/lib/libstrongswan.so ]; then
    echo "错误: libstrongswan 未安装"
    exit 1
fi

# 3. 编译 gmsm 插件
echo "[3/4] 编译 gmsm 插件..."
cd src/libstrongswan/plugins/gmsm

gcc -std=gnu99 -shared -fPIC \
    -I/usr/local/include \
    -I/usr/local/strongswan/include \
    -DHAVE_CONFIG_H \
    gmsm_plugin.c \
    gmsm_sm3_hasher.c \
    gmsm_sm4_crypter.c \
    gmsm_sm2_private_key.c \
    gmsm_sm2_public_key.c \
    -L/usr/local/lib \
    -L/usr/local/strongswan/lib \
    -lgmssl \
    -lstrongswan \
    -o libstrongswan-gmsm.so

echo "✓ gmsm 插件编译成功"

# 4. 安装插件
echo "[4/4] 安装 gmsm 插件..."
mkdir -p /usr/local/strongswan/lib/plugins
cp libstrongswan-gmsm.so /usr/local/strongswan/lib/plugins/
ldconfig

echo ""
echo "=== 编译完成 ==="
ls -lh libstrongswan-gmsm.so
nm -D libstrongswan-gmsm.so | grep -E "sm2|sm3|sm4" | head -10
