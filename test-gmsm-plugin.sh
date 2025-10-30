#!/bin/bash
# Test GMSM Plugin Integration
# Date: 2025-10-30

echo "========================================"
echo " GMSM 插件测试脚本"
echo "========================================"
echo ""

# Test 1: Check if gmsm plugin is loaded
echo "[测试 1] 检查 gmsm 插件是否已加载..."
if ldd /usr/lib/ipsec/plugins/libstrongswan-gmsm.so | grep -q libgmssl; then
    echo "✓ gmsm 插件链接到 libgmssl"
    ldd /usr/lib/ipsec/plugins/libstrongswan-gmsm.so | grep libgmssl
else
    echo "✗ gmsm 插件未正确链接 libgmssl"
fi

# Test 2: Check plugin symbols
echo ""
echo "[测试 2] 检查插件符号..."
if nm -D /usr/lib/ipsec/plugins/libstrongswan-gmsm.so | grep -q gmsm_plugin_create; then
    echo "✓ gmsm_plugin_create 符号存在"
else
    echo "✗ gmsm_plugin_create 符号不存在"
fi

# Test 3: List all exported functions
echo ""
echo "[测试 3] 导出的主要函数:"
nm -D /usr/lib/ipsec/plugins/libstrongswan-gmsm.so | grep ' T ' | grep -E 'gmsm|sm2|sm3|sm4'

# Test 4: Check swanctl algorithms
echo ""
echo "[测试 4] 检查 swanctl 支持的算法..."
if command -v swanctl &> /dev/null; then
    sudo swanctl --list-algs 2>/dev/null | grep -i sm || echo "swanctl 未运行或未显示 SM 算法"
else
    echo "swanctl 未安装"
fi

# Test 5: Generate SM2 key pair
echo ""
echo "[测试 5] 生成 SM2 密钥对测试..."
if command -v gmssl &> /dev/null; then
    echo "使用 GmSSL 生成 SM2 密钥..."
    gmssl sm2keygen -pass 1234 -out /tmp/test_sm2_key.pem -pubout /tmp/test_sm2_pub.pem 2>&1
    if [ -f /tmp/test_sm2_key.pem ]; then
        echo "✓ SM2 私钥已生成: /tmp/test_sm2_key.pem"
        echo "✓ SM2 公钥已生成: /tmp/test_sm2_pub.pem"
    else
        echo "✗ SM2 密钥生成失败"
    fi
else
    echo "gmssl 命令未找到"
fi

# Test 6: SM3 Hash test
echo ""
echo "[测试 6] SM3 哈希测试..."
echo "Hello, GM/T Cryptography!" | gmssl dgst -sm3 2>&1 || echo "SM3 哈希测试失败"

# Test 7: SM4 Encryption test
echo ""
echo "[测试 7] SM4 加密测试..."
echo "Test Data" > /tmp/test_plain.txt
gmssl sm4 -e -in /tmp/test_plain.txt -out /tmp/test_encrypted.bin -key 0123456789abcdef0123456789abcdef 2>&1
if [ -f /tmp/test_encrypted.bin ]; then
    echo "✓ SM4 加密成功"
    gmssl sm4 -d -in /tmp/test_encrypted.bin -out /tmp/test_decrypted.txt -key 0123456789abcdef0123456789abcdef 2>&1
    if diff /tmp/test_plain.txt /tmp/test_decrypted.txt > /dev/null 2>&1; then
        echo "✓ SM4 解密成功 - 数据匹配"
    else
        echo "✗ SM4 解密失败 - 数据不匹配"
    fi
else
    echo "✗ SM4 加密失败"
fi

# Test 8: Check strongswan.conf
echo ""
echo "[测试 8] 检查 strongswan.conf 配置..."
if grep -q 'gmsm' /etc/strongswan.conf 2>/dev/null; then
    echo "✓ strongswan.conf 中已配置 gmsm"
    grep -A3 'gmsm' /etc/strongswan.conf
else
    echo "⚠ strongswan.conf 中未配置 gmsm 插件"
    echo "  请添加以下配置:"
    echo ""
    echo "  charon {"
    echo "      plugins {"
    echo "          gmsm {"
    echo "              load = yes"
    echo "          }"
    echo "      }"
    echo "  }"
fi

# Cleanup
rm -f /tmp/test_*.{pem,txt,bin} 2>/dev/null

echo ""
echo "========================================"
echo " 测试完成"
echo "========================================"
