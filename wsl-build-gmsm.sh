#!/bin/bash
# gmsm 插件完整编译验证脚本 (WSL Ubuntu)
# 在 /mnt/c/Code/strongswan 目录执行

set -e

echo "=========================================="
echo "gmsm 插件完整编译验证"
echo "=========================================="
echo ""

# 检查当前目录
if [ ! -f "configure.ac" ]; then
    echo "错误: 请在 strongswan 源码根目录执行此脚本"
    exit 1
fi

# 1. 安装依赖
echo "步骤 1: 安装编译依赖..."
sudo apt update
sudo apt install -y \
    build-essential \
    autoconf automake libtool pkg-config \
    libssl-dev libgmp-dev libpam0g-dev \
    libsystemd-dev libcurl4-openssl-dev \
    libcap-ng-dev gettext wget cmake

echo "✓ 依赖安装完成"
echo ""

# 2. 编译安装 GmSSL
echo "步骤 2: 编译安装 GmSSL 3.1.1..."
if [ -f /usr/local/lib/libgmssl.so ]; then
    echo "GmSSL 已安装,跳过"
else
    cd /tmp
    wget -q https://github.com/guanzhi/GmSSL/archive/refs/tags/v3.1.1.tar.gz
    tar -zxf v3.1.1.tar.gz
    cd GmSSL-3.1.1
    mkdir -p build && cd build
    cmake -DCMAKE_C_FLAGS="-std=gnu99" ..
    make -j$(nproc)
    sudo make install
    sudo ldconfig
    cd -
    rm -rf /tmp/GmSSL-* /tmp/v3.1.1.tar.gz
    echo "✓ GmSSL 安装完成"
fi

# 验证 GmSSL
if [ -f /usr/local/lib/libgmssl.so ]; then
    ls -lh /usr/local/lib/libgmssl.so*
    echo "✓ GmSSL 验证通过"
else
    echo "✗ GmSSL 安装失败"
    exit 1
fi
echo ""

# 3. 返回源码目录并运行 autogen
echo "步骤 3: 运行 autogen.sh..."
cd /mnt/c/Code/strongswan
./autogen.sh

echo "✓ autogen.sh 完成"
echo ""

# 4. 配置
echo "步骤 4: 配置 strongSwan (启用 gmsm)..."
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-gmsm \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp \
    2>&1 | tee /tmp/configure.log

# 检查 gmsm 是否启用
if grep -q "gmsm.*yes" /tmp/configure.log || grep -q "USE_GMSM" config.h; then
    echo "✓ gmsm 插件已启用"
else
    echo "⚠ 警告: gmsm 可能未启用,请检查 configure 输出"
fi
echo ""

# 5. 编译
echo "步骤 5: 编译 strongSwan (可能需要几分钟)..."
make -j$(nproc) 2>&1 | tee /tmp/make.log

echo "✓ 编译完成"
echo ""

# 6. 验证 gmsm 插件
echo "步骤 6: 验证 gmsm 插件..."
PLUGIN_PATH="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"

if [ -f "$PLUGIN_PATH" ]; then
    echo "✓✓✓ gmsm 插件编译成功! ✓✓✓"
    echo ""
    ls -lh "$PLUGIN_PATH"
    echo ""
    
    echo "符号表检查:"
    echo "--------------------------------------"
    echo "导出的 gmsm 符号:"
    nm -D "$PLUGIN_PATH" | grep " T " | grep gmsm | head -10
    
    echo ""
    echo "未定义的 GmSSL 符号 (应该链接到 libgmssl.so):"
    nm -u "$PLUGIN_PATH" | grep -E "sm2_|sm3_|sm4_" | head -15
    
    echo ""
    echo "依赖库:"
    ldd "$PLUGIN_PATH" | grep -E "gmssl|ssl|crypto"
    
    echo ""
    echo "文件信息:"
    file "$PLUGIN_PATH"
    
else
    echo "✗ 插件未生成!"
    echo "检查编译日志: /tmp/make.log"
    echo ""
    echo "可能的错误:"
    grep -i error /tmp/make.log | tail -20
    exit 1
fi

echo ""
echo "=========================================="
echo "✓✓✓ 编译验证完成! ✓✓✓"
echo "=========================================="
echo ""
echo "插件位置: $PLUGIN_PATH"
echo "大小: $(du -h $PLUGIN_PATH | cut -f1)"
echo ""
echo "下一步:"
echo "1. 安装: sudo make install"
echo "2. 部署到云主机进行集成测试"
echo "3. 使用 swanctl-gmssl.conf 配置国密算法"
