#!/bin/bash
# 在现有Ubuntu容器中安装GmSSL和编译GMSM插件

set -e

echo "=========================================="
echo "  在现有容器中安装GmSSL和编译GMSM"
echo "=========================================="

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 检查是否在容器内
if [ ! -f /.dockerenv ] && [ ! -f /run/.containerenv ]; then
    echo -e "${YELLOW}警告: 似乎不在Docker容器内${NC}"
    echo "建议在容器内运行此脚本"
fi

# 1. 安装编译依赖（如果还没有）
echo -e "\n${YELLOW}[1/5] 检查并安装编译依赖...${NC}"
apt-get update -qq
apt-get install -y -qq \
    git cmake build-essential \
    autoconf automake libtool pkg-config \
    libgmp-dev libssl-dev \
    wget curl 2>&1 | grep -E "Setting up|installed" || true

echo -e "${GREEN}✓ 依赖已安装${NC}"

# 2. 安装GmSSL
echo -e "\n${YELLOW}[2/5] 检查GmSSL安装...${NC}"
if [ -f /usr/local/lib/libgmssl.so ] || [ -f /usr/local/lib/libgmssl.a ]; then
    echo -e "${GREEN}✓ GmSSL已安装${NC}"
    gmssl version 2>/dev/null || echo "GmSSL版本检查失败，继续..."
else
    echo "安装GmSSL 3.1.1..."
    cd /tmp
    if [ -d GmSSL ]; then
        rm -rf GmSSL
    fi
    
    git clone --depth 1 --branch v3.1.1 https://github.com/guanzhi/GmSSL.git
    cd GmSSL
    mkdir -p build && cd build
    cmake ..
    make -j$(nproc)
    make install
    ldconfig
    
    echo -e "${GREEN}✓ GmSSL安装完成${NC}"
    gmssl version
    
    cd /tmp
    rm -rf GmSSL
fi

# 3. 查找strongSwan源码目录
echo -e "\n${YELLOW}[3/5] 查找strongSwan源码...${NC}"
STRONGSWAN_DIR=""

# 可能的源码位置
for dir in /strongswan /opt/strongswan /usr/src/strongswan /root/strongswan; do
    if [ -f "$dir/configure.ac" ] || [ -f "$dir/configure" ]; then
        STRONGSWAN_DIR="$dir"
        break
    fi
done

if [ -z "$STRONGSWAN_DIR" ]; then
    echo -e "${RED}错误: 未找到strongSwan源码目录${NC}"
    echo "请确保源码已挂载到容器中"
    echo "尝试的位置: /strongswan, /opt/strongswan, /usr/src/strongswan"
    exit 1
fi

echo -e "${GREEN}✓ 找到strongSwan源码: $STRONGSWAN_DIR${NC}"
cd "$STRONGSWAN_DIR"

# 4. 检查GMSM插件代码
echo -e "\n${YELLOW}[4/5] 检查GMSM插件代码...${NC}"
if [ ! -d "src/libstrongswan/plugins/gmsm" ]; then
    echo -e "${RED}错误: GMSM插件目录不存在${NC}"
    echo "请确保插件代码在: src/libstrongswan/plugins/gmsm/"
    exit 1
fi

echo -e "${GREEN}✓ GMSM插件代码存在${NC}"
ls -la src/libstrongswan/plugins/gmsm/*.c | head -5

# 5. 编译
echo -e "\n${YELLOW}[5/5] 编译strongSwan和GMSM插件...${NC}"

# 清理之前的构建
if [ -f Makefile ]; then
    make clean 2>/dev/null || true
fi

# 生成configure（如果需要）
if [ ! -f configure ]; then
    echo "生成configure脚本..."
    ./autogen.sh || autoreconf -i
fi

# 配置
echo "配置strongSwan..."
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --enable-gmsm \
    --with-ipsecdir=/usr/libexec/ipsec \
    --with-systemdsystemunitdir=no

# 编译
echo "编译中..."
make -j$(nproc)

echo -e "\n${GREEN}=========================================="
echo "  编译完成！"
echo "==========================================${NC}"

# 检查插件
GMSM_PLUGIN=$(find . -name "libstrongswan-gmsm.so" 2>/dev/null | head -1)
if [ -n "$GMSM_PLUGIN" ]; then
    echo -e "${GREEN}✓ GMSM插件已生成: $GMSM_PLUGIN${NC}"
    ls -lh "$GMSM_PLUGIN"
    
    echo -e "\n${YELLOW}检查依赖:${NC}"
    ldd "$GMSM_PLUGIN" | grep -E "gmssl|not found" || true
    
    echo -e "\n${YELLOW}检查符号:${NC}"
    nm -D "$GMSM_PLUGIN" | grep -E "gmsm_plugin_create|sm2|sm3|sm4" | head -10
else
    echo -e "${RED}✗ 未找到GMSM插件${NC}"
    exit 1
fi

echo -e "\n${GREEN}下一步: 运行 'make install' 安装插件${NC}"
echo -e "或运行测试脚本验证功能"
