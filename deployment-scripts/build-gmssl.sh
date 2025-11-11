#!/bin/bash
# ============================================================================
# strongSwan + GmSSL Docker 构建脚本 (Bash)
# ============================================================================
# 使用说明:
#   ./build-gmssl.sh              # 使用缓存构建
#   ./build-gmssl.sh --no-cache   # 强制重新构建所有层
#   ./build-gmssl.sh --force      # 仅重新构建 strongSwan(跳过依赖和GmSSL缓存)
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# 解析参数
NO_CACHE=false
FORCE_UPDATE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --force)
            FORCE_UPDATE=true
            shift
            ;;
        *)
            echo -e "${RED}未知参数: $1${NC}"
            echo "使用方法: $0 [--no-cache|--force]"
            exit 1
            ;;
    esac
done

echo -e "${CYAN}============================================================================${NC}"
echo -e "${CYAN}  strongSwan + GmSSL Docker 镜像构建${NC}"
echo -e "${CYAN}============================================================================${NC}"
echo ""

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ 错误: 未找到 Docker。请先安装 Docker。${NC}"
    exit 1
fi

# 构建参数
BUILD_ARGS=""

if [ "$NO_CACHE" = true ]; then
    echo -e "${YELLOW}🔄 模式: 完全重新构建 (不使用任何缓存)${NC}"
    BUILD_ARGS="--no-cache"
elif [ "$FORCE_UPDATE" = true ]; then
    echo -e "${YELLOW}🔄 模式: 强制更新 strongSwan (保留依赖和GmSSL缓存)${NC}"
    # 使用时间戳作为 cache-bust 参数
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    BUILD_ARGS="--build-arg CACHE_BUST=$TIMESTAMP"
else
    echo -e "${GREEN}✅ 模式: 使用缓存构建 (推荐)${NC}"
fi

echo ""
echo -e "${CYAN}开始构建...${NC}"
echo ""

# 执行构建
echo -e "${GRAY}执行命令: docker-compose -f docker-compose.gmssl.yml build $BUILD_ARGS${NC}"
echo ""

if docker-compose -f docker-compose.gmssl.yml build $BUILD_ARGS; then
    echo ""
    echo -e "${GREEN}============================================================================${NC}"
    echo -e "${GREEN}  ✅ 构建成功!${NC}"
    echo -e "${GREEN}============================================================================${NC}"
    echo ""
    echo -e "${CYAN}验证镜像:${NC}"
    docker images | grep strongswan-gmssl
    echo ""
    echo -e "${CYAN}启动容器:${NC}"
    echo -e "${YELLOW}  docker-compose -f docker-compose.gmssl.yml up -d${NC}"
    echo ""
    echo -e "${CYAN}查看日志:${NC}"
    echo -e "${YELLOW}  docker-compose -f docker-compose.gmssl.yml logs -f${NC}"
    echo ""
else
    echo ""
    echo -e "${RED}============================================================================${NC}"
    echo -e "${RED}  ❌ 构建失败!${NC}"
    echo -e "${RED}============================================================================${NC}"
    echo ""
    echo -e "${YELLOW}故障排除提示:${NC}"
    echo -e "${GRAY}  1. 检查错误日志中的具体错误信息${NC}"
    echo -e "${GRAY}  2. 尝试清理 Docker 缓存: docker system prune -a${NC}"
    echo -e "${GRAY}  3. 使用 --no-cache 参数完全重新构建: ./build-gmssl.sh --no-cache${NC}"
    echo ""
    exit 1
fi
