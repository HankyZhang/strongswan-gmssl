# gmsm Plugin Verification Script
# Build and verify gmsm plugin in Docker

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " strongSwan gmsm Plugin Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build Docker image
Write-Host "Step 1: Building Docker build environment..." -ForegroundColor Yellow
docker build -f Dockerfile.gmsm-build -t strongswan-gmsm-builder .

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker image build failed" -ForegroundColor Red
    exit 1
}

Write-Host "Successfully built Docker image" -ForegroundColor Green
Write-Host ""

# Step 2: Compile and verify in container
Write-Host "Step 2: Compiling and verifying gmsm plugin in Docker..." -ForegroundColor Yellow
Write-Host ""

docker run --rm `
    -v "${PWD}:/workspace" `
    -w /workspace `
    strongswan-gmsm-builder `
    bash verify-gmsm-plugin.sh

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Verification script failed" -ForegroundColor Red
    Write-Host "Check output above for details" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Verification Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Check compilation logs for details"
Write-Host "2. If successful, deploy to cloud server for testing"
Write-Host "3. Run integration tests to verify SM2/SM3/SM4 functionality"
Write-Host ""
