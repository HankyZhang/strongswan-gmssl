#!/usr/bin/env pwsh
# 快速检查 strongSwan 容器状态

Write-Host "`n=== strongSwan + GmSSL 容器状态 ===" -ForegroundColor Cyan

# 检查容器是否运行
$container = docker ps --filter "name=strongswan-gmsm" --format "{{.Status}}"
if ($container) {
    Write-Host "✓ 容器状态: $container" -ForegroundColor Green
} else {
    Write-Host "✗ 容器未运行" -ForegroundColor Red
    exit 1
}

# 检查 charon 进程
Write-Host "`n--- charon 进程 ---" -ForegroundColor Yellow
docker exec strongswan-gmsm ps aux | Select-String "charon"

# 检查国密算法
Write-Host "`n--- 国密算法支持 ---" -ForegroundColor Yellow
docker exec strongswan-gmsm swanctl --list-algs 2>$null | Select-String -Pattern "SM|HASH_SM3|PRF_HMAC_SM3"

# 检查证书加载状态
Write-Host "`n--- 证书加载状态 ---" -ForegroundColor Yellow
$certs = docker exec strongswan-gmsm swanctl --list-certs 2>&1
if ($certs -match "subject:") {
    $certCount = ($certs | Select-String "subject:" | Measure-Object).Count
    Write-Host "✓ 已加载 $certCount 个证书" -ForegroundColor Green
} else {
    Write-Host "⚠ 未找到已加载的证书" -ForegroundColor Yellow
}

# 检查最新日志
Write-Host "`n--- 最新日志 (最后 10 行) ---" -ForegroundColor Yellow
docker exec strongswan-gmsm tail -n 10 /var/log/charon.log 2>$null

Write-Host "`n=================================`n" -ForegroundColor Cyan
