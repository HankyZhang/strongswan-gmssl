# PowerShell script to compile GMSM in existing container
Write-Host "Compiling GMSM plugin in existing strongswan container..." -ForegroundColor Cyan

$containerName = "strongswan"

# Check container
Write-Host "[1/4] Checking container status..." -ForegroundColor Yellow
$container = docker ps --filter "name=$containerName" --format "{{.Names}}"
if (-not $container) {
    Write-Host "Container not running, starting..." -ForegroundColor Red
    docker start $containerName
    Start-Sleep -Seconds 2
}
Write-Host "Container is running: $containerName" -ForegroundColor Green

# Copy source code
Write-Host "[2/4] Copying source code to container..." -ForegroundColor Yellow
docker exec $containerName rm -rf /strongswan 2>$null
docker exec $containerName mkdir -p /strongswan 2>$null
docker cp .\src $containerName`:/strongswan/
docker cp .\configure.ac $containerName`:/strongswan/
docker cp .\Makefile.am $containerName`:/strongswan/
docker cp .\autogen.sh $containerName`:/strongswan/ 2>$null
docker cp .\install-in-container.sh $containerName`:/tmp/
Write-Host "Source code copied" -ForegroundColor Green

# Compile
Write-Host "[3/4] Installing GmSSL and compiling GMSM..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes, please wait..." -ForegroundColor Gray
docker exec -it $containerName bash /tmp/install-in-container.sh

# Verify
Write-Host "[4/4] Verifying build..." -ForegroundColor Yellow
$plugin = docker exec $containerName find /strongswan -name "libstrongswan-gmsm.so" 2>$null
if ($plugin) {
    Write-Host "GMSM plugin compiled successfully!" -ForegroundColor Green
    Write-Host "Plugin location: $plugin" -ForegroundColor Cyan
} else {
    Write-Host "Plugin not found" -ForegroundColor Red
}
