#!/bin/bash
# 编译strongSwan GMSM插件的脚本

set -e  # 遇到错误立即退出

echo "=========================================="
echo "  strongSwan GMSM Plugin Build Script"
echo "=========================================="

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查GmSSL
echo -e "\n${YELLOW}[1/5] 检查GmSSL安装...${NC}"
if [ ! -f /usr/local/lib/libgmssl.so ]; then
    echo -e "${RED}错误: 未找到GmSSL库${NC}"
    exit 1
fi
echo -e "${GREEN}✓ GmSSL已安装${NC}"
gmssl version

# 清理之前的构建
echo -e "\n${YELLOW}[2/5] 清理之前的构建...${NC}"
if [ -f Makefile ]; then
    make clean 2>/dev/null || true
fi
rm -rf autom4te.cache config.log config.status

# 生成configure脚本
echo -e "\n${YELLOW}[3/5] 生成configure脚本...${NC}"
if [ ! -f configure ]; then
    if [ -f autogen.sh ]; then
        ./autogen.sh
    else
        autoreconf -i
    fi
fi

# 配置strongSwan
echo -e "\n${YELLOW}[4/5] 配置strongSwan (启用GMSM插件)...${NC}"
./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --enable-gmsm \
    --disable-aes \
    --disable-des \
    --disable-md5 \
    --disable-sha1 \
    --disable-sha2 \
    --disable-fips-prf \
    --disable-gmp \
    --disable-random \
    --disable-nonce \
    --disable-x509 \
    --disable-pubkey \
    --disable-pkcs1 \
    --disable-pkcs7 \
    --disable-pkcs8 \
    --disable-pkcs12 \
    --disable-pgp \
    --disable-dnskey \
    --disable-sshkey \
    --disable-pem \
    --disable-openssl \
    --disable-gcrypt \
    --disable-af-alg \
    --disable-curl \
    --disable-ldap \
    --disable-mysql \
    --disable-sqlite \
    --disable-stroke \
    --disable-vici \
    --enable-silent-rules \
    --with-systemdsystemunitdir=no

echo -e "${GREEN}✓ 配置完成${NC}"

# 编译
echo -e "\n${YELLOW}[5/5] 编译strongSwan和GMSM插件...${NC}"
make -j$(nproc)

echo -e "\n${GREEN}=========================================="
echo "  编译完成！"
echo "==========================================${NC}"

# 检查GMSM插件
GMSM_PLUGIN=$(find . -name "libstrongswan-gmsm.so" 2>/dev/null | head -1)
if [ -n "$GMSM_PLUGIN" ]; then
    echo -e "${GREEN}✓ GMSM插件已生成: $GMSM_PLUGIN${NC}"
    ls -lh "$GMSM_PLUGIN"
else
    echo -e "${RED}✗ 未找到GMSM插件${NC}"
    exit 1
fi

# 检查依赖
echo -e "\n${YELLOW}检查插件依赖:${NC}"
ldd "$GMSM_PLUGIN" | grep -E "gmssl|not found" || true

echo -e "\n${GREEN}下一步: 运行测试脚本验证插件功能${NC}"
