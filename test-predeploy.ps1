# Local Pre-deployment Test
# Test the configuration locally before deploying to cloud servers

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "strongSwan SM2/SM3/SM4 Pre-deployment Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build the image
Write-Host "[1/5] Building Docker image..." -ForegroundColor Yellow
docker build -f Dockerfile.gmssl -t strongswan-gmssl:latest . 2>&1 | Select-String -Pattern "Successfully|error" | Select-Object -Last 5
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Image built successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Verify image size
Write-Host "[2/5] Checking image size..." -ForegroundColor Yellow
$imageInfo = docker images strongswan-gmssl:latest --format "{{.Size}}"
Write-Host "Image size: $imageInfo" -ForegroundColor Cyan
Write-Host ""

# Step 3: Test server container startup
Write-Host "[3/5] Testing server container..." -ForegroundColor Yellow
docker stop test-server 2>$null | Out-Null
docker rm test-server 2>$null | Out-Null
docker run -d --name test-server --privileged strongswan-gmssl:latest
Start-Sleep -Seconds 8

$serverStatus = docker exec test-server ps aux | Select-String "charon"
if ($serverStatus) {
    Write-Host "✓ Server charon process running" -ForegroundColor Green
} else {
    Write-Host "ERROR: Server charon not running" -ForegroundColor Red
    docker logs test-server
    exit 1
}
Write-Host ""

# Step 4: Test certificate generation
Write-Host "[4/5] Testing certificate generation..." -ForegroundColor Yellow
docker exec test-server bash -c @"
cd /tmp
gmssl sm2keygen -pass 123456 -out test-key.pem 2>&1 | grep -v '^$'
gmssl certgen -C CN -O Test -CN test.example.com -days 365 -key test-key.pem -pass 123456 -out test-cert.pem 2>&1 | grep -v '^$'
if [ -f test-cert.pem ]; then
    echo 'Certificate generated successfully'
else
    echo 'ERROR: Certificate generation failed'
    exit 1
fi
"@ 2>&1 | Select-String -Pattern "success|ERROR|BEGIN"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Certificate generation working" -ForegroundColor Green
} else {
    Write-Host "ERROR: Certificate generation failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 5: Test credential loading
Write-Host "[5/5] Testing credential loading..." -ForegroundColor Yellow
docker exec test-server bash -c @"
cd /tmp
cp test-cert.pem /etc/swanctl/x509/
cp test-key.pem /etc/swanctl/private/
swanctl --load-creds 2>&1 | grep -E 'loaded|SM2'
"@ 2>&1 | Select-String -Pattern "loaded|SM2"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Credential loading working" -ForegroundColor Green
} else {
    Write-Host "ERROR: Credential loading failed" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Cleanup
Write-Host "Cleaning up test containers..." -ForegroundColor Yellow
docker stop test-server 2>$null | Out-Null
docker rm test-server 2>$null | Out-Null

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ All pre-deployment tests PASSED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ready for cloud deployment!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Export image:    docker save strongswan-gmssl:latest -o strongswan-gmssl.tar" -ForegroundColor Cyan
Write-Host "2. Compress:        gzip strongswan-gmssl.tar" -ForegroundColor Cyan
Write-Host "3. Upload to servers using SCP" -ForegroundColor Cyan
Write-Host "4. Follow docs/CLOUD-DEPLOYMENT-GUIDE.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "Image location: strongswan-gmssl:latest" -ForegroundColor Cyan
Write-Host "Deployment scripts:" -ForegroundColor Cyan
Write-Host "  - deployment-scripts/deploy-server.sh" -ForegroundColor Cyan
Write-Host "  - deployment-scripts/deploy-client.sh" -ForegroundColor Cyan
