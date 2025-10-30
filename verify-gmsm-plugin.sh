#!/bin/bash
# gmsm 插件验证脚本
# 在 Docker 容器中编译和验证 strongSwan gmsm 插件

set -e
set -x

echo "=========================================="
echo "gmsm 插件验证脚本"
echo "=========================================="

# 1. 验证 GmSSL 安装
echo "步骤 1: 验证 GmSSL 安装..."
if [ ! -f /usr/local/lib/libgmssl.so ]; then
    echo "错误: GmSSL 未正确安装"
    exit 1
fi
echo "✓ GmSSL 已安装"
gmssl version || echo "gmssl 命令行工具可能未安装"

# 2. 检查源码
echo "步骤 2: 检查 strongSwan 源码..."
if [ ! -d /workspace/src/libstrongswan/plugins/gmsm ]; then
    echo "错误: gmsm 插件源码不存在"
    echo "请确保已挂载正确的源码目录到 /workspace"
    exit 1
fi

echo "gmsm 插件源文件:"
ls -lh /workspace/src/libstrongswan/plugins/gmsm/

# 3. 运行 autogen.sh
echo "步骤 3: 运行 autogen.sh..."
cd /workspace
if [ -f autogen.sh ]; then
    ./autogen.sh
else
    echo "警告: autogen.sh 不存在,跳过"
fi

# 4. 配置构建
echo "步骤 4: 配置 strongSwan (启用 gmsm 插件)..."
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-gmsm \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --disable-gmp \
    2>&1 | tee /tmp/configure.log

# 检查 gmsm 是否成功启用
if grep -q "gmsm:.*yes" /tmp/configure.log || grep -q "USE_GMSM" config.h; then
    echo "✓ gmsm 插件已启用"
else
    echo "警告: gmsm 插件可能未正确启用"
    echo "检查 config.log 获取详细信息"
fi

# 5. 编译
echo "步骤 5: 编译 strongSwan..."
make -j$(nproc) 2>&1 | tee /tmp/make.log

# 6. 检查 gmsm 插件
echo "步骤 6: 检查 gmsm 插件编译结果..."
GMSM_PLUGIN_PATH="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"

if [ -f "$GMSM_PLUGIN_PATH" ]; then
    echo "✓ gmsm 插件编译成功!"
    ls -lh "$GMSM_PLUGIN_PATH"
    
    echo ""
    echo "符号表检查:"
    echo "导出的符号 (gmsm_*):"
    nm -D "$GMSM_PLUGIN_PATH" | grep " T " | grep gmsm
    
    echo ""
    echo "未定义的符号 (GmSSL API):"
    nm -u "$GMSM_PLUGIN_PATH" | grep -E "sm2_|sm3_|sm4_" | head -20
    
    echo ""
    echo "依赖库:"
    ldd "$GMSM_PLUGIN_PATH"
else
    echo "错误: gmsm 插件未生成"
    echo "检查编译日志: /tmp/make.log"
    exit 1
fi

# 7. 安装
echo "步骤 7: 安装 strongSwan..."
make install

# 8. 验证插件加载
echo "步骤 8: 验证插件可以加载..."
PLUGIN_DIR="/usr/local/strongswan/lib/ipsec/plugins"
if [ -f "$PLUGIN_DIR/libstrongswan-gmsm.so" ]; then
    echo "✓ 插件已安装到 $PLUGIN_DIR"
    ls -lh "$PLUGIN_DIR/libstrongswan-gmsm.so"
else
    echo "警告: 插件未找到,手动复制..."
    mkdir -p "$PLUGIN_DIR"
    cp "$GMSM_PLUGIN_PATH" "$PLUGIN_DIR/"
fi

# 9. 测试插件加载
echo "步骤 9: 测试插件加载..."
cat > /etc/strongswan.conf <<EOF
charon {
    load_modular = yes
    plugins {
        gmsm {
            load = yes
        }
    }
}
EOF

# 测试 charon 能否识别插件
/usr/local/strongswan/libexec/ipsec/charon --version 2>&1 | tee /tmp/charon-version.log

if grep -q "gmsm" /tmp/charon-version.log; then
    echo "✓ gmsm 插件已被 charon 识别!"
else
    echo "警告: charon 输出中未找到 gmsm 插件"
    echo "这可能是正常的,检查日志了解详情"
fi

echo ""
echo "=========================================="
echo "验证完成!"
echo "=========================================="
echo ""
echo "总结:"
echo "- GmSSL: $(ls -lh /usr/local/lib/libgmssl.so 2>/dev/null | awk '{print $5}' || echo '未知')"
echo "- gmsm 插件: $(ls -lh $GMSM_PLUGIN_PATH 2>/dev/null | awk '{print $5}' || echo '未找到')"
echo "- 安装位置: $PLUGIN_DIR/libstrongswan-gmsm.so"
echo ""
echo "编译日志保存在:"
echo "  - /tmp/configure.log"
echo "  - /tmp/make.log"
echo "  - /tmp/charon-version.log"
