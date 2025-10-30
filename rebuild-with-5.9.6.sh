#!/bin/bash
#
# strongSwan 5.9.6 + gmsm 插件完整构建脚本
# 用途: 切换到稳定版本并集成 gmsm 插件
# 
# 使用方法:
#   WSL: bash /mnt/c/Code/strongswan/rebuild-with-5.9.6.sh
#   云服务器: 先上传此脚本,然后 bash rebuild-with-5.9.6.sh
#

set -e  # 遇到错误立即退出

# ============================================================================
# 配置变量
# ============================================================================
STRONGSWAN_VERSION="5.9.6"
BUILD_DIR="/tmp/strongswan-5.9.6-gmsm"
SOURCE_DIR="/mnt/c/Code/strongswan"  # Windows 源码位置 (WSL 路径)
INSTALL_PREFIX="/usr"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 辅助函数
# ============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ============================================================================
# 步骤 1: 检查依赖
# ============================================================================
log_info "检查系统依赖..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 未安装"
        return 1
    fi
    log_success "$1 已安装"
}

check_command wget || sudo apt-get install -y wget
check_command autoconf || sudo apt-get install -y autoconf
check_command automake || sudo apt-get install -y automake
check_command libtool || sudo apt-get install -y libtool
check_command gperf || sudo apt-get install -y gperf
check_command flex || sudo apt-get install -y flex
check_command bison || sudo apt-get install -y bison
check_command pkg-config || sudo apt-get install -y pkg-config

# 检查 GmSSL
if [ ! -f /usr/local/lib/libgmssl.so ]; then
    log_error "GmSSL 未安装! 请先安装 GmSSL 3.1.x"
    exit 1
fi
log_success "GmSSL 已安装: $(ls -l /usr/local/lib/libgmssl.so* | head -1)"

# ============================================================================
# 步骤 2: 下载 strongSwan 5.9.6
# ============================================================================
log_info "准备构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

log_info "下载 strongSwan $STRONGSWAN_VERSION..."
if [ ! -f "strongswan-$STRONGSWAN_VERSION.tar.gz" ]; then
    wget "https://download.strongswan.org/strongswan-$STRONGSWAN_VERSION.tar.gz"
fi

log_info "解压源码..."
tar -zxf "strongswan-$STRONGSWAN_VERSION.tar.gz"
cd "strongswan-$STRONGSWAN_VERSION"

# ============================================================================
# 步骤 3: 复制 gmsm 插件源码
# ============================================================================
log_info "复制 gmsm 插件源码..."

# 创建 gmsm 插件目录
mkdir -p src/libstrongswan/plugins/gmsm

# 检查源码目录是否存在
if [ -d "$SOURCE_DIR/src/libstrongswan/plugins/gmsm" ]; then
    cp -r "$SOURCE_DIR/src/libstrongswan/plugins/gmsm/"* \
       src/libstrongswan/plugins/gmsm/
    log_success "gmsm 插件源码已复制"
else
    log_error "找不到 gmsm 源码: $SOURCE_DIR/src/libstrongswan/plugins/gmsm"
    log_warning "请确认 Windows 路径正确,或手动复制源码"
    exit 1
fi

# ============================================================================
# 步骤 4: 复制修改的枚举定义文件
# ============================================================================
log_info "复制修改的枚举定义文件..."

copy_if_exists() {
    local src="$SOURCE_DIR/$1"
    local dst="$1"
    if [ -f "$src" ]; then
        cp "$src" "$dst"
        log_success "已复制: $1"
    else
        log_warning "文件不存在: $src"
    fi
}

copy_if_exists "src/libstrongswan/crypto/crypters/crypter.h"
copy_if_exists "src/libstrongswan/crypto/hashers/hasher.h"
copy_if_exists "src/libstrongswan/credentials/keys/public_key.h"
copy_if_exists "src/libstrongswan/credentials/keys/public_key.c"

# ============================================================================
# 步骤 5: 修改 configure.ac
# ============================================================================
log_info "修改 configure.ac..."

# 检查是否已包含 gmsm Makefile
if grep -q "src/libstrongswan/plugins/gmsm/Makefile" configure.ac; then
    log_success "configure.ac 已包含 gmsm Makefile"
else
    log_warning "configure.ac 未包含 gmsm Makefile,需要手动添加"
    
    # 尝试自动添加 (在 openssl 插件后)
    if grep -q "src/libstrongswan/plugins/openssl/Makefile" configure.ac; then
        sed -i '/src\/libstrongswan\/plugins\/openssl\/Makefile/a\src/libstrongswan/plugins/gmsm/Makefile' configure.ac
        log_success "已自动添加 gmsm Makefile 到 configure.ac"
    else
        log_error "无法自动添加,请手动编辑 configure.ac"
        echo "需要在 AC_CONFIG_FILES 列表中添加:"
        echo "  src/libstrongswan/plugins/gmsm/Makefile"
        exit 1
    fi
fi

# 检查并添加 --enable-gmsm 选项 (如果不存在)
if ! grep -q "ARG_ENABL_SET.*gmsm" configure.ac; then
    log_warning "configure.ac 未定义 --enable-gmsm 选项"
    log_info "在 plugins 配置部分添加..."
    
    # 在 openssl 选项后添加 (需要找到合适的位置)
    if grep -n "ARG_ENABL_SET.*openssl" configure.ac > /dev/null; then
        LINE=$(grep -n "ARG_ENABL_SET.*openssl" configure.ac | head -1 | cut -d: -f1)
        sed -i "${LINE}a\\ARG_ENABL_SET([gmsm],        [enable Chinese SM2/SM3/SM4 crypto plugin (GmSSL).])" configure.ac
        log_success "已添加 --enable-gmsm 选项"
    fi
fi

# ============================================================================
# 步骤 6: 修改 src/libstrongswan/Makefile.am
# ============================================================================
log_info "修改 src/libstrongswan/Makefile.am..."

MAKEFILE_AM="src/libstrongswan/Makefile.am"

if grep -q "plugins/gmsm" "$MAKEFILE_AM"; then
    log_success "Makefile.am 已包含 gmsm"
else
    log_info "添加 gmsm 到 SUBDIRS..."
    
    # 在 SUBDIRS 的 plugins 部分添加
    # 注意: 这里需要根据实际的 Makefile.am 结构调整
    if grep -q "if MONOLITHIC" "$MAKEFILE_AM"; then
        sed -i '/if MONOLITHIC/a\  SUBDIRS += plugins/gmsm' "$MAKEFILE_AM"
    else
        log_warning "无法自动添加,请手动编辑 $MAKEFILE_AM"
        echo "在 SUBDIRS 中添加: plugins/gmsm"
    fi
fi

# ============================================================================
# 步骤 7: 转换换行符 (如果需要)
# ============================================================================
log_info "检查文件格式..."

if file configure.ac | grep -q "CRLF"; then
    log_warning "检测到 CRLF 换行符,转换为 LF..."
    sed -i 's/\r$//' configure.ac
    log_success "已转换为 LF 格式"
fi

# ============================================================================
# 步骤 8: 运行 autogen.sh
# ============================================================================
log_info "运行 autogen.sh..."
./autogen.sh 2>&1 | tee /tmp/autogen.log

if [ $? -ne 0 ]; then
    log_error "autogen.sh 失败! 查看日志: /tmp/autogen.log"
    tail -50 /tmp/autogen.log
    exit 1
fi
log_success "autogen.sh 成功"

# ============================================================================
# 步骤 9: 配置
# ============================================================================
log_info "运行 configure..."

./configure \
  --prefix="$INSTALL_PREFIX" \
  --sysconfdir=/etc \
  --enable-gmsm \
  --enable-openssl \
  --enable-swanctl \
  --enable-vici \
  --disable-gmp \
  --with-systemdsystemunitdir=no \
  2>&1 | tee /tmp/configure.log

if [ $? -ne 0 ]; then
    log_error "configure 失败! 查看日志: /tmp/configure.log"
    tail -50 /tmp/configure.log
    exit 1
fi

# 验证 gmsm Makefile 是否生成
if [ -f src/libstrongswan/plugins/gmsm/Makefile ]; then
    log_success "configure 成功 - gmsm Makefile 已生成"
else
    log_error "configure 失败 - gmsm Makefile 未生成"
    exit 1
fi

# ============================================================================
# 步骤 10: 编译
# ============================================================================
log_info "开始编译 (使用 $(nproc) 个 CPU 核心)..."

make -j$(nproc) 2>&1 | tee /tmp/make.log

if [ $? -ne 0 ]; then
    log_error "编译失败! 查看错误:"
    tail -100 /tmp/make.log | grep -E '(error:|undefined reference)'
    exit 1
fi

log_success "编译成功!"

# ============================================================================
# 步骤 11: 检查 gmsm 插件是否编译
# ============================================================================
log_info "验证 gmsm 插件..."

GMSM_SO="src/libstrongswan/plugins/gmsm/.libs/libstrongswan-gmsm.so"
if [ -f "$GMSM_SO" ]; then
    log_success "gmsm 插件已编译: $GMSM_SO"
    ls -lh "$GMSM_SO"
else
    log_error "gmsm 插件未编译!"
    log_info "检查编译日志:"
    grep -i gmsm /tmp/make.log | tail -20
    exit 1
fi

# ============================================================================
# 步骤 12: 安装 (可选)
# ============================================================================
read -p "是否安装到系统? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "安装到 $INSTALL_PREFIX..."
    sudo make install
    sudo ldconfig
    log_success "安装完成!"
    
    # 验证安装
    if [ -f "$INSTALL_PREFIX/lib/ipsec/plugins/libstrongswan-gmsm.so" ]; then
        log_success "gmsm 插件已安装"
    fi
    
    # 测试插件列表
    log_info "测试插件加载..."
    if command -v swanctl &> /dev/null; then
        swanctl --list-plugins | grep -i gmsm && \
            log_success "gmsm 插件可以加载!" || \
            log_warning "gmsm 插件未在列表中"
    fi
else
    log_info "跳过安装,编译产物在: $BUILD_DIR/strongswan-$STRONGSWAN_VERSION"
fi

# ============================================================================
# 完成
# ============================================================================
echo ""
echo "========================================================================"
log_success "strongSwan 5.9.6 + gmsm 插件构建完成!"
echo "========================================================================"
echo ""
echo "构建目录: $BUILD_DIR/strongswan-$STRONGSWAN_VERSION"
echo "编译日志: /tmp/make.log"
echo "gmsm 插件: $GMSM_SO"
echo ""
echo "下一步:"
echo "  1. 测试插件: swanctl --list-plugins | grep gmsm"
echo "  2. 生成 SM2 证书"
echo "  3. 配置 VPN 连接"
echo "  4. 完整测试"
echo ""
echo "详细文档: $SOURCE_DIR/问题总结和解决方案.md"
echo "========================================================================"
