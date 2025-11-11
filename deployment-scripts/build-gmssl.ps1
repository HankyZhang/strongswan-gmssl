# ============================================================================
# strongSwan + GmSSL Docker Build Script (PowerShell)
# ============================================================================
# Usage:
#   .\build-gmssl.ps1              # Build with cache
#   .\build-gmssl.ps1 -NoCache     # Rebuild all layers
#   .\build-gmssl.ps1 -ForceUpdate # Rebuild strongSwan only (keep deps cache)
# ============================================================================

param(
    [switch]$NoCache,      # No cache at all
    [switch]$ForceUpdate   # Force update strongSwan code (keep deps and GmSSL cache)
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan + GmSSL Docker Image Build" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Build arguments
$buildArgs = @()

if ($NoCache) {
    Write-Host "Mode: Full rebuild (no cache)" -ForegroundColor Yellow
    $buildArgs += "--no-cache"
} elseif ($ForceUpdate) {
    Write-Host "Mode: Force update strongSwan (keep deps and GmSSL cache)" -ForegroundColor Yellow
    # Use timestamp as cache-bust parameter
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $buildArgs += "--build-arg", "CACHE_BUST=$timestamp"
} else {
    Write-Host "Mode: Build with cache (recommended)" -ForegroundColor Green
}

Write-Host ""
Write-Host "Starting build..." -ForegroundColor Cyan
Write-Host ""

# Execute build
$command = "docker-compose -f docker-compose.gmssl.yml build $($buildArgs -join ' ')"
Write-Host "Command: $command" -ForegroundColor Gray
Write-Host ""

try {
    Invoke-Expression $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "============================================================================" -ForegroundColor Green
        Write-Host "  Build successful!" -ForegroundColor Green
        Write-Host "============================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Verify image:" -ForegroundColor Cyan
        docker images | Select-String "strongswan-gmssl"
        Write-Host ""
        Write-Host "Start container:" -ForegroundColor Cyan
        Write-Host "  docker-compose -f docker-compose.gmssl.yml up -d" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "View logs:" -ForegroundColor Cyan
        Write-Host "  docker-compose -f docker-compose.gmssl.yml logs -f" -ForegroundColor Yellow
        Write-Host ""
    } else {
        throw "Build failed with exit code: $LASTEXITCODE"
    }
} catch {
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host "  Build failed!" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Check error logs for specific errors" -ForegroundColor Gray
    Write-Host "  2. Clean Docker cache: docker system prune -a" -ForegroundColor Gray
    Write-Host "  3. Full rebuild: .\build-gmssl.ps1 -NoCache" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
