#!/bin/bash
# strongSwan gmsm 插件云主机编译脚本
# 使用 ~/strongswan-gmssl 已克隆的修改版源码

set -e
set -x

echo "=========================================="
echo "strongSwan gmsm 插件编译脚本"
echo "=========================================="

# 1. 检查 GmSSL 是否已安装
echo "步骤 1: 检查 GmSSL 安装..."
if [ ! -f /usr/local/lib/libgmssl.so.3.1 ]; then
    echo "错误: GmSSL 未安装在 /usr/local"
    exit 1
fi
echo "✓ GmSSL 3.1.1 已安装"

# 2. 进入源码目录
echo "步骤 2: 进入 strongSwan 源码目录..."
cd ~/strongswan-gmssl
echo "当前目录: $(pwd)"

# 3. 检查 gmsm 插件源文件
echo "步骤 3: 检查 gmsm 插件源文件..."
GMSM_DIR="src/libstrongswan/plugins/gmsm"
if [ ! -d "$GMSM_DIR" ]; then
    echo "错误: $GMSM_DIR 不存在"
    exit 1
fi

echo "gmsm 插件源文件:"
ls -lh $GMSM_DIR/*.c

# 4. 手动编译 gmsm 插件
echo "步骤 4: 手动编译 gmsm 插件..."
cd $GMSM_DIR

# 编译选项
GCC_FLAGS="-std=gnu99 -shared -fPIC -Wall -Wextra"
# 关键: 从 src/libstrongswan/plugins/gmsm/ 目录
# ../../ = src/libstrongswan/
# 所以 #include <plugins/plugin.h> 会找到 src/libstrongswan/plugins/plugin.h
INCLUDE_PATHS="-I../.. -I/usr/local/include"
DEFINES="-D_GNU_SOURCE -DHAVE_CONFIG_H"
LIBS="-L/usr/local/lib -lgmssl"

# 源文件
SOURCES="gmsm_plugin.c gmsm_sm3_hasher.c gmsm_sm4_crypter.c gmsm_sm2_private_key.c gmsm_sm2_public_key.c"

# 输出文件
OUTPUT="libstrongswan-gmsm.so"

echo "编译命令:"
echo "gcc $GCC_FLAGS $INCLUDE_PATHS $DEFINES $SOURCES $LIBS -o $OUTPUT"

gcc $GCC_FLAGS $INCLUDE_PATHS $DEFINES $SOURCES $LIBS -o $OUTPUT

# 5. 检查编译结果
echo "步骤 5: 检查编译结果..."
if [ ! -f "$OUTPUT" ]; then
    echo "错误: 编译失败,未生成 $OUTPUT"
    exit 1
fi

echo "✓ 编译成功!"
ls -lh $OUTPUT

# 6. 检查符号表
echo "步骤 6: 检查符号表..."
echo "导出的符号:"
nm -D $OUTPUT | grep -E "gmsm_plugin_create|T "

echo "未定义的符号 (应该包含 sm2_, sm3_, sm4_):"
nm -u $OUTPUT | grep -E "sm2_|sm3_|sm4_"

# 7. 检查依赖库
echo "步骤 7: 检查依赖库..."
ldd $OUTPUT

echo "=========================================="
echo "编译完成! 插件位置:"
echo "$(pwd)/$OUTPUT"
echo "=========================================="
echo ""
echo "下一步:"
echo "1. 安装插件: cp $OUTPUT /usr/local/strongswan/lib/ipsec/plugins/"
echo "2. 配置加载: echo 'load = gmsm' >> /etc/strongswan.conf"
echo "3. 测试加载: /usr/local/strongswan/sbin/charon --version"
