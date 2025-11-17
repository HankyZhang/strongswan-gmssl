#!/usr/bin/env pwsh
# SM2 国密算法集成测试脚本
# 用于验证 strongSwan + GmSSL 的完整功能

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " strongSwan + GmSSL SM2 集成测试" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. 清理旧容器
Write-Host "[1/6] 清理旧容器..." -ForegroundColor Yellow
docker rm -f strongswan-gmsm 2>$null
Start-Sleep -Seconds 1

# 2. 启动新容器 (必须使用 --privileged 或 --cap-add)
Write-Host "[2/6] 启动新容器 (--privileged 模式)..." -ForegroundColor Yellow
docker run -d --name strongswan-gmsm --privileged strongswan-gmssl:latest /start.sh
Start-Sleep -Seconds 6

# 3. 验证 charon 进程
Write-Host "[3/6] 检查 charon 进程状态..." -ForegroundColor Yellow
$charonProc = docker exec strongswan-gmsm ps aux | Select-String "charon"
if ($charonProc) {
    Write-Host "✓ charon 进程运行正常" -ForegroundColor Green
    Write-Host $charonProc
} else {
    Write-Host "✗ charon 进程未运行！" -ForegroundColor Red
    docker logs strongswan-gmsm --tail 50
    exit 1
}

# 4. 列出算法
Write-Host "`n[4/6] 列出支持的国密算法..." -ForegroundColor Yellow
$algs = docker exec strongswan-gmsm swanctl --list-algs | Select-String -Pattern "SM|sm"
if ($algs) {
    Write-Host "✓ 国密算法已加载:" -ForegroundColor Green
    $algs | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "✗ 未找到国密算法！" -ForegroundColor Red
    exit 1
}

# 5. 加载证书
Write-Host "`n[5/6] 加载 SM2 证书..." -ForegroundColor Yellow
$loadOutput = docker exec strongswan-gmsm swanctl --load-creds 2>&1
Write-Host $loadOutput

if ($loadOutput -match "undefined symbol") {
    Write-Host "✗ 符号未定义错误 - GmSSL 构建可能有问题" -ForegroundColor Red
    exit 1
} elseif ($loadOutput -match "parsing.*failed") {
    Write-Host "⚠ 证书解析失败 - 可能是 SM2 格式问题" -ForegroundColor Yellow
} else {
    Write-Host "✓ 证书加载命令执行完成" -ForegroundColor Green
}

# 6. 列出证书
Write-Host "`n[6/6] 列出已加载的证书..." -ForegroundColor Yellow
$certs = docker exec strongswan-gmsm swanctl --list-certs 2>&1
Write-Host $certs

# 总结
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " 测试完成" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 可选：查看详细日志
Write-Host "`n提示: 查看详细日志使用以下命令:" -ForegroundColor Gray
Write-Host '  docker logs strongswan-gmsm --tail 100' -ForegroundColor Gray
Write-Host '  docker exec strongswan-gmsm cat /var/log/charon.log' -ForegroundColor Gray
