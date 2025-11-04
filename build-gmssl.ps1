# ============================================================================
# strongSwan + GmSSL Docker 构建脚本 (PowerShell)
# ============================================================================
# 使用说明:
#   .\build-gmssl.ps1              # 使用缓存构建
#   .\build-gmssl.ps1 -NoCache     # 强制重新构建所有层
#   .\build-gmssl.ps1 -ForceUpdate # 仅重新构建 strongSwan(跳过依赖和GmSSL缓存)
# ============================================================================

param(
    [switch]$NoCache,      # 完全不使用缓存
    [switch]$ForceUpdate   # 强制更新 strongSwan 代码(保留依赖和GmSSL缓存)
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan + GmSSL Docker 镜像构建" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# 检查 Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "❌ 错误: 未找到 Docker。请先安装 Docker Desktop。" -ForegroundColor Red
    exit 1
}

# 构建参数
$buildArgs = @()

if ($NoCache) {
    Write-Host "🔄 模式: 完全重新构建 (不使用任何缓存)" -ForegroundColor Yellow
    $buildArgs += "--no-cache"
} elseif ($ForceUpdate) {
    Write-Host "🔄 模式: 强制更新 strongSwan (保留依赖和GmSSL缓存)" -ForegroundColor Yellow
    # 使用时间戳作为 cache-bust 参数
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $buildArgs += "--build-arg", "CACHE_BUST=$timestamp"
} else {
    Write-Host "✅ 模式: 使用缓存构建 (推荐)" -ForegroundColor Green
}

Write-Host ""
Write-Host "开始构建..." -ForegroundColor Cyan
Write-Host ""

# 执行构建
$command = "docker-compose -f docker-compose.gmssl.yml build $($buildArgs -join ' ')"
Write-Host "执行命令: $command" -ForegroundColor Gray
Write-Host ""

try {
    Invoke-Expression $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "============================================================================" -ForegroundColor Green
        Write-Host "  ✅ 构建成功!" -ForegroundColor Green
        Write-Host "============================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "验证镜像:" -ForegroundColor Cyan
        docker images | Select-String "strongswan-gmssl"
        Write-Host ""
        Write-Host "启动容器:" -ForegroundColor Cyan
        Write-Host "  docker-compose -f docker-compose.gmssl.yml up -d" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "查看日志:" -ForegroundColor Cyan
        Write-Host "  docker-compose -f docker-compose.gmssl.yml logs -f" -ForegroundColor Yellow
        Write-Host ""
    } else {
        throw "构建失败,退出码: $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "  ❌ 构建失败!" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "错误信息: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "故障排除提示:" -ForegroundColor Yellow
    Write-Host "  1. 检查错误日志中的具体错误信息" -ForegroundColor Gray
    Write-Host "  2. 尝试清理 Docker 缓存: docker system prune -a" -ForegroundColor Gray
    Write-Host "  3. 使用 -NoCache 参数完全重新构建: .\build-gmssl.ps1 -NoCache" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
