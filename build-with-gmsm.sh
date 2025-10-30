#!/bin/bash
# strongSwan with GMSM Plugin - Complete Build Script
# Date: 2025-10-30

set -e

BUILD_DIR="/tmp/strongswan-gmsm-final2/strongswan-5.9.6"
LOG_FILE="/tmp/gmsm-build.log"

echo "========================================="
echo " StrongSwan GMSM 插件编译脚本"
echo "========================================="
echo ""

# Step 1: Check GmSSL
echo "[1/5] 检查 GmSSL 库..."
if [ ! -f /usr/local/lib/libgmssl.so.3.1 ]; then
    echo "错误: GmSSL 库未找到!"
    echo "请先安装 GmSSL 3.1.1"
    exit 1
fi
echo "✓ GmSSL 库已安装"

# Step 2: Configure
echo ""
echo "[2/5] 配置编译选项..."
cd "$BUILD_DIR"

./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --enable-gmsm \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp \
    --with-systemdsystemunitdir=no \
    > "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 配置完成"
    grep -E 'gmsm.*yes' "$LOG_FILE" && echo "✓ gmsm 插件已启用"
else
    echo "✗ 配置失败,查看日志: $LOG_FILE"
    exit 1
fi

# Step 3: Make clean
echo ""
echo "[3/5] 清理旧编译..."
make clean >> "$LOG_FILE" 2>&1
echo "✓ 清理完成"

# Step 4: Compile
echo ""
echo "[4/5] 开始编译 (这可能需要几分钟)..."
make -j$(nproc) >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✓ 编译成功!"
else
    echo "✗ 编译失败"
    echo "错误信息:"
    tail -50 "$LOG_FILE"
    exit 1
fi

# Step 5: Check gmsm plugin
echo ""
echo "[5/5] 检查 gmsm 插件..."
GMSM_SO="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"

if [ -f "$GMSM_SO" ]; then
    echo "✓ gmsm 插件已生成!"
    ls -lh "$GMSM_SO"*
    echo ""
    echo "检查符号:"
    nm -D "$GMSM_SO" | grep -E 'gmsm_plugin|sm3|sm4|sm2' | head -10
else
    echo "✗ gmsm 插件未生成"
    echo "检查 src/libstrongswan/plugins/gmsm/ 目录:"
    ls -la src/libstrongswan/plugins/gmsm/
    exit 1
fi

echo ""
echo "========================================="
echo " 编译成功!"
echo "========================================="
echo ""
echo "下一步:"
echo "  sudo make install"
echo "  配置 /etc/strongswan.conf 启用 gmsm 插件"
echo ""
echo "完整日志: $LOG_FILE"
