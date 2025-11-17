#!/usr/bin/env pwsh
# 检查 GmSSL 库是否正确导出 sm2_private_key_info_from_pem 符号

Write-Host "`n=== GmSSL 符号导出验证 ===" -ForegroundColor Cyan

# 检查 libgmssl.so 中的符号
Write-Host "`n[1] 检查 libgmssl.so 导出的 SM2 符号..." -ForegroundColor Yellow
docker exec strongswan-gmsm nm -D /usr/local/lib/libgmssl.so.3 2>$null | Select-String "sm2_private_key"

# 检查 gmsm 插件链接
Write-Host "`n[2] 检查 gmsm 插件的库依赖..." -ForegroundColor Yellow
docker exec strongswan-gmsm ldd /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so 2>$null | Select-String "gmssl"

# 尝试加载证书（测试符号解析）
Write-Host "`n[3] 测试证书加载（符号解析测试）..." -ForegroundColor Yellow
$output = docker exec strongswan-gmsm swanctl --load-creds 2>&1
if ($output -match "undefined symbol") {
    Write-Host "✗ 符号未定义错误:" -ForegroundColor Red
    Write-Host $output -ForegroundColor Red
} else {
    Write-Host "✓ 无符号错误，证书加载命令成功执行" -ForegroundColor Green
    Write-Host $output
}

Write-Host "`n=================================`n" -ForegroundColor Cyan
