#!/bin/bash
# 快速测试国密算法集成
# 使用 Docker 环境
# Date: 2025-11-04

echo "=========================================="
echo " 国密算法快速测试"
echo " 使用 Docker 容器进行测试"
echo "=========================================="
echo ""

# 检查 Docker 镜像是否存在
if ! docker images | grep -q "strongswan-gmssl"; then
    echo "❌ strongswan-gmssl Docker 镜像不存在"
    echo "   请先运行: docker-compose -f docker-compose.gmssl.yml build"
    exit 1
fi

echo "✓ Docker 镜像已找到"
echo ""

# 启动临时容器进行测试
echo "[步骤 1] 启动测试容器..."
CONTAINER_ID=$(docker run -d --rm --privileged strongswan-gmssl:3.1.1 sleep 300)

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ 无法启动容器"
    exit 1
fi

echo "✓ 容器已启动: $CONTAINER_ID"
echo ""

# 测试 GmSSL 是否已安装
echo "[测试 1] 检查 GmSSL 版本..."
docker exec $CONTAINER_ID gmssl version

# 测试 SM2 密钥生成
echo ""
echo "[测试 2] 生成 SM2 密钥对..."
docker exec $CONTAINER_ID gmssl sm2keygen -pass 1234 -out /tmp/sm2_key.pem -pubout /tmp/sm2_pub.pem
if [ $? -eq 0 ]; then
    echo "✓ SM2 密钥生成成功"
else
    echo "❌ SM2 密钥生成失败"
fi

# 测试 SM3 哈希
echo ""
echo "[测试 3] SM3 哈希测试..."
docker exec $CONTAINER_ID sh -c 'echo "Hello GM/T" | gmssl dgst -sm3'
if [ $? -eq 0 ]; then
    echo "✓ SM3 哈希测试成功"
else
    echo "❌ SM3 哈希测试失败"
fi

# 测试 SM4 加密
echo ""
echo "[测试 4] SM4 加密测试..."
docker exec $CONTAINER_ID sh -c 'echo "Test Data" | gmssl sm4 -e -key 0123456789abcdef0123456789abcdef | gmssl sm4 -d -key 0123456789abcdef0123456789abcdef'
if [ $? -eq 0 ]; then
    echo "✓ SM4 加密/解密测试成功"
else
    echo "❌ SM4 加密/解密测试失败"
fi

# 检查 strongSwan 插件
echo ""
echo "[测试 5] 检查 strongSwan gmsm 插件..."
docker exec $CONTAINER_ID ls -lh /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✓ gmsm 插件已安装"
    docker exec $CONTAINER_ID ldd /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so | grep gmssl
else
    echo "⚠ gmsm 插件未找到"
fi

# 检查算法支持
echo ""
echo "[测试 6] 检查 strongSwan 支持的算法..."
docker exec $CONTAINER_ID /usr/local/strongswan/sbin/swanctl --list-algs 2>/dev/null | grep -i sm || echo "⚠ swanctl 未显示 SM 算法（可能需要配置）"

# 清理
echo ""
echo "[清理] 停止测试容器..."
docker stop $CONTAINER_ID > /dev/null

echo ""
echo "=========================================="
echo " 测试完成"
echo "=========================================="
