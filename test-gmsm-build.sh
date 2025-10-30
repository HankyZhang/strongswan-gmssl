#!/bin/bash
#
# strongSwan gmsm 插件云端编译测试脚本
# 适用于: CentOS 7
# 日期: 2025-10-30
#

set -e

echo "========================================="
echo " strongSwan gmsm 插件编译测试"
echo "========================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
    exit 1
fi

# 1. 安装基础工具
echo -e "${YELLOW}[1/6] 安装基础工具...${NC}"
yum install -y git wget gcc make autoconf automake libtool \
    pkgconfig gettext-devel 2>&1 | grep -E "Installing|Complete|已安装" || true

# 2. 安装 GmSSL 依赖
echo -e "${YELLOW}[2/6] 安装 GmSSL 依赖...${NC}"
yum install -y cmake3 2>&1 | grep -E "Installing|Complete|已安装" || true
ln -sf /usr/bin/cmake3 /usr/bin/cmake

# 3. 编译安装 GmSSL 3.1.1
echo -e "${YELLOW}[3/6] 编译安装 GmSSL 3.1.1...${NC}"
if [ ! -d "/usr/local/include/gmssl" ]; then
    cd /tmp
    if [ ! -d "GmSSL" ]; then
        git clone --depth 1 --branch v3.1.1 https://github.com/guanzhi/GmSSL.git
    fi
    cd GmSSL
    mkdir -p build && cd build
    # 修复 C99 语法错误：强制使用 C99 标准
    export CFLAGS="-std=c99 -D_POSIX_C_SOURCE=200809L"
    cmake .. \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_FLAGS="-std=c99 -D_POSIX_C_SOURCE=200809L" \
        -DENABLE_SM2_PRIVATE=ON \
        -DENABLE_SM3=ON \
        -DENABLE_SM4=ON
    make -j $(nproc)
    make install
    ldconfig
    echo -e "${GREEN}✓ GmSSL 3.1.1 安装成功${NC}"
else
    echo -e "${GREEN}✓ GmSSL 已安装${NC}"
fi

# 验证 GmSSL
if [ -f "/usr/local/include/gmssl/sm3.h" ]; then
    echo -e "${GREEN}✓ GmSSL 头文件验证成功${NC}"
else
    echo -e "${RED}✗ GmSSL 头文件未找到${NC}"
    exit 1
fi

# 4. 克隆 strongSwan 源码
echo -e "${YELLOW}[4/6] 克隆 strongSwan 源码...${NC}"
cd /root
if [ -d "strongswan" ]; then
    echo "  strongswan 目录已存在，拉取最新代码..."
    cd strongswan
    git pull
else
    git clone https://github.com/HankyZhang/strongswan-gmssl.git strongswan
    cd strongswan
fi

# 5. 安装 strongSwan 编译依赖
echo -e "${YELLOW}[5/6] 安装 strongSwan 编译依赖...${NC}"
yum install -y \
    gmp-devel \
    openssl-devel \
    pam-devel \
    systemd-devel \
    libcurl-devel 2>&1 | grep -E "Installing|Complete|已安装" || true

# 6. 编译 strongSwan 带 gmsm 插件
echo -e "${YELLOW}[6/6] 编译 strongSwan 带 gmsm 插件...${NC}"

# 生成构建系统
echo "  运行 autogen.sh..."
./autogen.sh

# 配置
echo "  配置编译选项..."
./configure \
    --prefix=/usr/local/strongswan \
    --sysconfdir=/etc \
    --enable-gmsm \
    --with-gmssl=/usr/local \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --enable-systemd \
    --disable-gmp

# 编译
echo "  编译中..."
make -j $(nproc)

# 检查 gmsm 插件是否编译成功
if [ -f "src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so" ]; then
    echo -e "${GREEN}✓ gmsm 插件编译成功${NC}"
    ls -lh src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so
else
    echo -e "${RED}✗ gmsm 插件编译失败${NC}"
    exit 1
fi

# 7. 测试符号链接
echo ""
echo -e "${YELLOW}检查 gmsm 插件符号...${NC}"
nm src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so | grep -E "gmsm_sm3|gmsm_sm4|gmsm_plugin" || true

# 8. 检查依赖
echo ""
echo -e "${YELLOW}检查 GmSSL 依赖...${NC}"
ldd src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so | grep gmssl || echo "  注意: 未链接 libgmssl (可能是静态链接)"

echo ""
echo "========================================="
echo -e "${GREEN}✓ 编译测试完成！${NC}"
echo "========================================="
echo ""
echo "下一步操作:"
echo "  1. 安装: make install"
echo "  2. 测试 SM3 哈希"
echo "  3. 测试 SM4 加密"
echo ""

# 显示构建信息
echo "构建摘要:"
echo "  GmSSL: $(ls -d /usr/local/include/gmssl 2>/dev/null && echo '✓ 已安装' || echo '✗ 未找到')"
echo "  gmsm 插件: $(ls src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so 2>/dev/null && echo '✓ 已编译' || echo '✗ 未找到')"
echo "  插件大小: $(du -h src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so 2>/dev/null | cut -f1)"
