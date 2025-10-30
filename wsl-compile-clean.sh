#!/bin/bash
# WSL 中完整编译 strongSwan + gmsm 插件
# 适用于 Windows 文件系统的特殊处理

set -e

echo "=========================================="
echo "strongSwan + gmsm 插件编译 (WSL)"
echo "=========================================="

# 工作目录
WORK_DIR="/tmp/strongswan-build"
SOURCE_DIR="/mnt/c/Code/strongswan"

# 清理并创建工作目录
echo "步骤 1: 准备工作目录..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 复制源码到 Linux 文件系统(避免 Windows 文件系统权限问题)
echo "步骤 2: 复制源代码到 Linux 文件系统..."
rsync -a --exclude='.git' "$SOURCE_DIR/" "$WORK_DIR/"
echo "✓ 源代码复制完成"

# 验证 gmsm 插件源码
echo ""
echo "步骤 3: 验证 gmsm 插件源码..."
if [ ! -f "src/libstrongswan/plugins/gmsm/gmsm_plugin.c" ]; then
    echo "❌ 错误: gmsm 插件源码不存在"
    exit 1
fi
echo "✓ gmsm 插件源码存在"
ls -lh src/libstrongswan/plugins/gmsm/*.c | awk '{print "  -", $9, "("$5")"}'

# 确保 GmSSL 已安装
echo ""
echo "步骤 4: 检查 GmSSL..."
if [ ! -f "/usr/local/lib/libgmssl.so.3.1" ]; then
    echo "❌ 错误: GmSSL 未安装,请先运行 wsl-build-gmsm.sh 的步骤 2"
    exit 1
fi
echo "✓ GmSSL 已安装: $(ls -lh /usr/local/lib/libgmssl.so.3.1 | awk '{print $5}')"
sudo ldconfig

# 运行 autogen.sh
echo ""
echo "步骤 5: 生成 configure 脚本..."
bash autogen.sh
echo "✓ configure 生成完成"

# 配置编译选项
echo ""
echo "步骤 6: 配置编译选项..."
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export CFLAGS="-I/usr/local/include -std=gnu99"
export LDFLAGS="-L/usr/local/lib"

./configure \
    --prefix=/usr/local/strongswan \
    --enable-gmsm \
    --enable-openssl \
    --disable-random \
    --disable-aes \
    --disable-des \
    --disable-md5 \
    --disable-sha1 \
    --disable-sha2 \
    --disable-hmac \
    --disable-xcbc \
    --disable-cmac \
    --disable-nonce \
    --sysconfdir=/etc \
    --with-ipseclibdir=/usr/local/strongswan/lib/ipsec

echo "✓ 配置完成"

# 编译
echo ""
echo "步骤 7: 编译 strongSwan + gmsm 插件..."
make -j$(nproc)
echo "✓ 编译完成"

# 验证插件
echo ""
echo "步骤 8: 验证 gmsm 插件..."
PLUGIN_PATH="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ ! -f "$PLUGIN_PATH" ]; then
    echo "❌ 错误: 插件未生成"
    exit 1
fi

echo "✓ 插件生成成功:"
ls -lh "$PLUGIN_PATH"

echo ""
echo "检查插件符号:"
nm -D "$PLUGIN_PATH" | grep -E "gmsm_plugin_create|sm2_|sm3_|sm4_" | head -20

echo ""
echo "检查插件依赖:"
ldd "$PLUGIN_PATH" | grep -E "libgmssl|libc"

# 复制插件回 Windows 文件系统
echo ""
echo "步骤 9: 复制插件到 Windows 文件系统..."
mkdir -p "$SOURCE_DIR/build-output"
cp "$PLUGIN_PATH" "$SOURCE_DIR/build-output/libstrongswan-gmsm.so"
cp "src/libstrongswan/.libs/libstrongswan.so.0" "$SOURCE_DIR/build-output/" 2>/dev/null || true
echo "✓ 插件已复制到: $SOURCE_DIR/build-output/"

echo ""
echo "=========================================="
echo "✅ 编译成功完成!"
echo "=========================================="
echo ""
echo "编译产物:"
echo "  - 插件: $SOURCE_DIR/build-output/libstrongswan-gmsm.so"
echo "  - 大小: $(ls -lh $SOURCE_DIR/build-output/libstrongswan-gmsm.so | awk '{print $5}')"
echo ""
echo "下一步:"
echo "  1. 将插件部署到云服务器"
echo "  2. 切换配置为 swanctl-gmssl.conf"
echo "  3. 测试 SM2/SM3/SM4 VPN 连接"
echo ""
