#!/bin/bash
#
# gmsm 插件编译问题诊断和修复脚本
# 
# 问题: "Skipping gmsm" - 编译时跳过 gmsm 插件
# 原因: Makefile 未由 automake 生成,仍是占位符
#
# 解决方案: 
# 1. 确保 Windows 的修改同步到 WSL
# 2. 重新运行完整的构建流程
# 3. 验证条件宏正确设置
#

set -e  # 遇到错误立即退出

BUILD_DIR="/tmp/strongswan-gmsm-final2/strongswan-5.9.6"
WIN_SRC="/mnt/c/Code/strongswan"

echo "================================================"
echo "  gmsm 插件编译修复脚本"
echo "================================================"

cd "$BUILD_DIR"

echo ""
echo "[1/7] 同步 configure.ac 从 Windows 到 WSL..."
cp "$WIN_SRC/configure.ac" ./

echo "[2/7] 同步 Makefile.am 从 Windows 到 WSL..."
cp "$WIN_SRC/src/libstrongswan/plugins/gmsm/Makefile.am" \
   src/libstrongswan/plugins/gmsm/

echo "[3/7] 清理旧的生成文件..."
cd src/libstrongswan/plugins/gmsm
rm -f Makefile Makefile.in .deps/*
cd "$BUILD_DIR"

echo "[4/7] 重新运行 autogen.sh..."
./autogen.sh 2>&1 | tail -5

echo "[5/7] 重新 configure with --enable-gmsm..."
./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --enable-gmsm \
  --enable-openssl \
  --enable-swanctl \
  --enable-vici \
  --disable-gmp \
  --with-systemdsystemunitdir=no \
  2>&1 | grep -E '(gmsm|Checking)' | tail -10

echo ""
echo "[6/7] 验证 gmsm 插件配置..."
echo -n "  - USE_GMSM 条件宏: "
if grep -q "USE_GMSM_TRUE='#'" config.status; then
    echo "❌ 未启用"
    echo ""
    echo "错误: configure 未正确启用 gmsm 插件"
    echo "建议: 检查 configure.ac 中的 ARG_ENABL_SET 和 ADD_PLUGIN 定义"
    exit 1
elif grep -q "USE_GMSM_FALSE='#'" config.status; then
    echo "✅ 已启用"
else
    echo "⚠️  未知状态"
fi

echo -n "  - Makefile.in 已生成: "
if [ -f "src/libstrongswan/plugins/gmsm/Makefile.in" ]; then
    echo "✅"
else
    echo "❌"
    echo ""
    echo "错误: automake 未生成 Makefile.in"
    exit 1
fi

echo -n "  - Makefile 已生成: "
if [ -f "src/libstrongswan/plugins/gmsm/Makefile" ]; then
    # 检查是否是真正的 Makefile 而不是占位符
    if grep -q "Skipping gmsm" "src/libstrongswan/plugins/gmsm/Makefile"; then
        echo "❌ (仍是占位符)"
        exit 1
    else
        echo "✅"
    fi
else
    echo "❌"
    exit 1
fi

echo ""
echo "[7/7] 开始编译 gmsm 插件..."
make clean 2>&1 | tail -3
make -j4 2>&1 | grep -E '(gmsm|Making all in plugins/gmsm|\.libs/libstrongswan-gmsm)' | head -20

echo ""
echo "================================================"
echo "  检查编译结果"
echo "================================================"

if [ -f "src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so" ]; then
    echo "✅ gmsm 插件编译成功!"
    echo ""
    ls -lh src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so*
    echo ""
    echo "链接库检查:"
    ldd src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so | grep gmssl
else
    echo "❌ gmsm 插件编译失败"
    echo ""
    echo "最后 50 行编译日志:"
    make V=1 2>&1 | tail -50
    exit 1
fi

echo ""
echo "================================================"
echo "  修复完成!"
echo "================================================"
echo ""
echo "下一步:"
echo "  sudo make install"
echo "  bash $WIN_SRC/test-gmsm-plugin.sh"
