#!/bin/bash
#
# strongSwan 5.9.6 + gmsm 手动构建脚本 (简化版)
# 
# 使用方法:
#   WSL: bash /mnt/c/Code/strongswan/build-gmsm-5.9.6-manual.sh
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== strongSwan 5.9.6 + gmsm 手动构建 ===${NC}"

# 1. 准备目录
BUILD_DIR="/tmp/strongswan-5.9.6-gmsm-manual"
SOURCE_DIR="/mnt/c/Code/strongswan"

echo -e "${YELLOW}步骤 1/8: 清理并创建构建目录...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 2. 下载源码
echo -e "${YELLOW}步骤 2/8: 下载 strongSwan 5.9.6...${NC}"
if [ ! -f strongswan-5.9.6.tar.gz ]; then
    wget https://download.strongswan.org/strongswan-5.9.6.tar.gz
fi
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6

# 3. 复制 gmsm 插件源码
echo -e "${YELLOW}步骤 3/8: 复制 gmsm 插件源码...${NC}"
mkdir -p src/libstrongswan/plugins/gmsm
cp -r "$SOURCE_DIR/src/libstrongswan/plugins/gmsm/"* \
   src/libstrongswan/plugins/gmsm/

# 4. 复制修改的枚举文件
echo -e "${YELLOW}步骤 4/8: 复制修改的枚举定义...${NC}"
cp "$SOURCE_DIR/src/libstrongswan/crypto/crypters/crypter.h" \
   src/libstrongswan/crypto/crypters/
cp "$SOURCE_DIR/src/libstrongswan/crypto/hashers/hasher.h" \
   src/libstrongswan/crypto/hashers/
cp "$SOURCE_DIR/src/libstrongswan/credentials/keys/public_key.h" \
   src/libstrongswan/credentials/keys/
cp "$SOURCE_DIR/src/libstrongswan/credentials/keys/public_key.c" \
   src/libstrongswan/credentials/keys/

# 5. 修改 configure.ac - 添加 gmsm Makefile
echo -e "${YELLOW}步骤 5/8: 修改 configure.ac...${NC}"
if ! grep -q 'src/libstrongswan/plugins/gmsm/Makefile' configure.ac; then
    sed -i '/src\/libstrongswan\/plugins\/openssl\/Makefile/a\        src/libstrongswan/plugins/gmsm/Makefile' configure.ac
    echo -e "${GREEN}✓ 已添加 gmsm Makefile${NC}"
else
    echo -e "${GREEN}✓ gmsm Makefile 已存在${NC}"
fi

# 添加 --enable-gmsm 选项
if ! grep -q 'ARG_ENABL_SET.*gmsm' configure.ac; then
    sed -i '/ARG_ENABL_SET(\[openssl\]/a\ARG_ENABL_SET([gmsm],        [enable Chinese SM2/SM3/SM4 crypto plugin (GmSSL).])' configure.ac
    echo -e "${GREEN}✓ 已添加 --enable-gmsm 选项${NC}"
else
    echo -e "${GREEN}✓ --enable-gmsm 选项已存在${NC}"
fi

# 6. 修改 src/libstrongswan/Makefile.am - 添加 gmsm 构建规则
echo -e "${YELLOW}步骤 6/8: 修改 src/libstrongswan/Makefile.am...${NC}"

# 清除之前错误添加的行
sed -i '/if MONOLITHIC/,/SUBDIRS += plugins\/gmsm/d' src/libstrongswan/Makefile.am

# 在 openssl 插件后添加 gmsm
if ! grep -q 'if USE_GMSM' src/libstrongswan/Makefile.am; then
    # 找到 USE_OPENSSL 部分的结束 endif
    LINE=$(grep -n 'if USE_OPENSSL' src/libstrongswan/Makefile.am | cut -d: -f1)
    END_LINE=$((LINE + 5))
    
    # 在 openssl 的 endif 后插入 gmsm 部分
    sed -i "${END_LINE}a\\
\\
if USE_GMSM\\
  SUBDIRS += plugins/gmsm\\
if MONOLITHIC\\
  libstrongswan_la_LIBADD += plugins/gmsm/libstrongswan-gmsm.la\\
endif\\
endif" src/libstrongswan/Makefile.am
    
    echo -e "${GREEN}✓ 已添加 gmsm 构建规则${NC}"
else
    echo -e "${GREEN}✓ gmsm 构建规则已存在${NC}"
fi

# 7. 运行 configure (不需要 autogen.sh, 因为 5.9.6 是发布版本)
echo -e "${YELLOW}步骤 7/8: 运行 configure...${NC}"

# 首先需要重新生成 configure 脚本(因为我们修改了 configure.ac)
echo -e "${BLUE}重新生成 configure 脚本...${NC}"
autoreconf -fi

./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --enable-openssl \
  --enable-swanctl \
  --enable-vici \
  --disable-gmp \
  --with-systemdsystemunitdir=no \
  2>&1 | tee /tmp/configure-gmsm.log

# 检查 gmsm Makefile 是否生成
if [ -f src/libstrongswan/plugins/gmsm/Makefile ]; then
    echo -e "${GREEN}✓ configure 成功 - gmsm Makefile 已生成${NC}"
else
    echo -e "${YELLOW}⚠ configure 完成但 gmsm Makefile 未生成${NC}"
    echo "检查配置日志: /tmp/configure-gmsm.log"
fi

# 8. 编译
echo -e "${YELLOW}步骤 8/8: 编译 strongSwan...${NC}"
make -j$(nproc) 2>&1 | tee /tmp/make-gmsm.log

# 检查 gmsm 插件是否编译
GMSM_SO="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ -f "$GMSM_SO" ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✓✓✓ 成功!gmsm 插件已编译!${NC}"
    echo -e "${GREEN}========================================${NC}"
    ls -lh "$GMSM_SO"
    
    echo ""
    echo "下一步:"
    echo "  sudo make install"
    echo "  sudo ldconfig"
    echo "  swanctl --list-plugins | grep gmsm"
else
    echo -e "${YELLOW}⚠ 编译完成但 gmsm 插件未生成${NC}"
    echo "检查最后的错误:"
    grep -i 'error.*gmsm\|gmsm.*error' /tmp/make-gmsm.log | tail -20
fi

echo ""
echo "构建目录: $BUILD_DIR/strongswan-5.9.6"
echo "配置日志: /tmp/configure-gmsm.log"
echo "编译日志: /tmp/make-gmsm.log"
