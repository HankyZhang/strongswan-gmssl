#!/bin/bash
# 测试strongSwan GMSM插件的脚本

set -e

echo "=========================================="
echo "  strongSwan GMSM Plugin Test Script"
echo "=========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 查找GMSM插件
GMSM_PLUGIN=$(find /strongswan -name "libstrongswan-gmsm.so" 2>/dev/null | head -1)
if [ -z "$GMSM_PLUGIN" ]; then
    echo -e "${RED}错误: 未找到GMSM插件${NC}"
    exit 1
fi

echo -e "${GREEN}找到GMSM插件: $GMSM_PLUGIN${NC}"

# 测试1: 检查符号
echo -e "\n${YELLOW}[测试1] 检查插件导出的符号...${NC}"
nm -D "$GMSM_PLUGIN" | grep -E "gmsm_plugin_create|gmsm_sm" | head -10 || true

# 测试2: 检查依赖
echo -e "\n${YELLOW}[测试2] 检查插件依赖...${NC}"
ldd "$GMSM_PLUGIN"

# 测试3: 使用ipsec工具测试
echo -e "\n${YELLOW}[测试3] 检查strongSwan可执行文件...${NC}"
IPSEC=$(find /strongswan -name "ipsec" -type f -executable 2>/dev/null | head -1)
if [ -n "$IPSEC" ]; then
    echo -e "${GREEN}找到ipsec: $IPSEC${NC}"
    
    # 设置库路径
    export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
    
    # 尝试列出插件
    echo -e "\n${YELLOW}尝试列出所有插件...${NC}"
    $IPSEC pki --options 2>&1 | grep -i "plugin" || true
else
    echo -e "${YELLOW}未编译ipsec工具（正常，因为禁用了很多功能）${NC}"
fi

# 测试4: 创建简单的测试程序
echo -e "\n${YELLOW}[测试4] 创建测试程序验证插件加载...${NC}"

cat > /tmp/test_gmsm.c << 'EOF'
#include <stdio.h>
#include <library.h>
#include <plugins/plugin_loader.h>

int main() {
    printf("初始化 strongSwan 库...\n");
    
    if (!library_init(NULL, "test_gmsm")) {
        printf("错误: 库初始化失败\n");
        return 1;
    }
    
    if (!lib->plugins->load(lib->plugins, PLUGINS)) {
        printf("错误: 插件加载失败\n");
        library_deinit();
        return 1;
    }
    
    printf("✓ strongSwan库初始化成功\n");
    
    // 检查hasher
    printf("\n检查支持的哈希算法:\n");
    enumerator_t *enumerator;
    hash_algorithm_t algo;
    enumerator = lib->crypto->create_hasher_enumerator(lib->crypto);
    while (enumerator->enumerate(enumerator, &algo)) {
        printf("  - %N\n", hash_algorithm_names, algo);
    }
    enumerator->destroy(enumerator);
    
    // 检查crypter
    printf("\n检查支持的加密算法:\n");
    encryption_algorithm_t enc_algo;
    size_t key_size;
    enumerator = lib->crypto->create_crypter_enumerator(lib->crypto);
    while (enumerator->enumerate(enumerator, &enc_algo, &key_size)) {
        printf("  - %N (key_size: %zu)\n", 
               encryption_algorithm_names, enc_algo, key_size);
    }
    enumerator->destroy(enumerator);
    
    // 检查PRF
    printf("\n检查支持的PRF算法:\n");
    pseudo_random_function_t prf_algo;
    enumerator = lib->crypto->create_prf_enumerator(lib->crypto);
    while (enumerator->enumerate(enumerator, &prf_algo)) {
        printf("  - %N\n", pseudo_random_function_names, prf_algo);
    }
    enumerator->destroy(enumerator);
    
    library_deinit();
    printf("\n✓ 测试完成\n");
    return 0;
}
EOF

# 尝试编译测试程序
if gcc -o /tmp/test_gmsm /tmp/test_gmsm.c \
    -I/strongswan/src/libstrongswan \
    -L/strongswan/src/libstrongswan/.libs \
    -lstrongswan \
    -Wl,-rpath,/strongswan/src/libstrongswan/.libs 2>/dev/null; then
    
    echo -e "${GREEN}测试程序编译成功${NC}"
    echo -e "\n${YELLOW}运行测试程序...${NC}"
    
    export LD_LIBRARY_PATH=/strongswan/src/libstrongswan/.libs:/usr/local/lib:$LD_LIBRARY_PATH
    export PLUGINS_DIR=/strongswan/src/libstrongswan/plugins
    
    /tmp/test_gmsm || true
else
    echo -e "${YELLOW}测试程序编译失败（正常，可能缺少头文件）${NC}"
fi

echo -e "\n${GREEN}=========================================="
echo "  测试脚本执行完成"
echo "==========================================${NC}"

echo -e "\n${YELLOW}建议:${NC}"
echo "1. 如果看到 SM3/SM4 相关输出，说明插件注册成功"
echo "2. 可以尝试 'make install' 安装到系统"
echo "3. 运行 strongSwan 守护进程进行完整测试"
