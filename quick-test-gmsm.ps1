# 快速测试国密算法集成
# 使用 Docker 环境
# Date: 2025-11-04

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 国密算法快速测试" -ForegroundColor Cyan
Write-Host " 使用 Docker 容器进行测试" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Docker 镜像是否存在
Write-Host "[检查] 查找 Docker 镜像..."
$imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "strongswan-gmssl:3.1.1"

if (-not $imageExists) {
    Write-Host "❌ strongswan-gmssl Docker 镜像不存在" -ForegroundColor Red
    Write-Host "   请先运行: docker-compose -f docker-compose.gmssl.yml build" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Docker 镜像已找到: $imageExists" -ForegroundColor Green
Write-Host ""

# 启动临时容器进行测试
Write-Host "[步骤 1] 启动测试容器..." -ForegroundColor Yellow
$containerId = docker run -d --rm --privileged strongswan-gmssl:3.1.1 sleep 300

if (-not $containerId) {
    Write-Host "❌ 无法启动容器" -ForegroundColor Red
    exit 1
}

Write-Host "✓ 容器已启动: $containerId" -ForegroundColor Green
Write-Host ""

try {
    # 测试 GmSSL 是否已安装
    Write-Host "[测试 1] 检查 GmSSL 版本..." -ForegroundColor Yellow
    docker exec $containerId gmssl version
    Write-Host ""

    # 测试 SM2 密钥生成
    Write-Host "[测试 2] 生成 SM2 密钥对..." -ForegroundColor Yellow
    docker exec $containerId gmssl sm2keygen -pass 1234 -out /tmp/sm2_key.pem -pubout /tmp/sm2_pub.pem
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ SM2 密钥生成成功" -ForegroundColor Green
    } else {
        Write-Host "❌ SM2 密钥生成失败" -ForegroundColor Red
    }
    Write-Host ""

    # 测试 SM3 哈希
    Write-Host "[测试 3] SM3 哈希测试..." -ForegroundColor Yellow
    docker exec $containerId sh -c 'echo "Hello GM/T" | gmssl dgst -sm3'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ SM3 哈希测试成功" -ForegroundColor Green
    } else {
        Write-Host "❌ SM3 哈希测试失败" -ForegroundColor Red
    }
    Write-Host ""

    # 测试 SM4 加密
    Write-Host "[测试 4] SM4 加密测试..." -ForegroundColor Yellow
    docker exec $containerId sh -c 'echo "Test Data" | gmssl sm4 -e -key 0123456789abcdef0123456789abcdef | gmssl sm4 -d -key 0123456789abcdef0123456789abcdef'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ SM4 加密/解密测试成功" -ForegroundColor Green
    } else {
        Write-Host "❌ SM4 加密/解密测试失败" -ForegroundColor Red
    }
    Write-Host ""

    # 检查 strongSwan 插件
    Write-Host "[测试 5] 检查 strongSwan gmsm 插件..." -ForegroundColor Yellow
    $pluginCheck = docker exec $containerId ls -lh /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ gmsm 插件已安装" -ForegroundColor Green
        docker exec $containerId ldd /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so
    } else {
        Write-Host "⚠ gmsm 插件未找到" -ForegroundColor Yellow
    }
    Write-Host ""

    # 检查算法支持
    Write-Host "[测试 6] 检查 strongSwan 支持的算法..." -ForegroundColor Yellow
    $algs = docker exec $containerId /usr/local/strongswan/sbin/swanctl --list-algs 2>$null
    if ($algs -match "SM") {
        Write-Host $algs | Select-String "SM"
    } else {
        Write-Host "⚠ swanctl 未显示 SM 算法（可能需要配置）" -ForegroundColor Yellow
    }
    Write-Host ""

    # 运行完整的测试脚本（如果存在）
    Write-Host "[测试 7] 运行完整测试脚本..." -ForegroundColor Yellow
    docker exec $containerId test -f /tmp/test-gmsm-plugin.sh
    if ($LASTEXITCODE -eq 0) {
        docker exec $containerId bash /tmp/test-gmsm-plugin.sh
    }

} finally {
    # 清理
    Write-Host ""
    Write-Host "[清理] 停止测试容器..." -ForegroundColor Yellow
    docker stop $containerId | Out-Null
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 测试完成" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
