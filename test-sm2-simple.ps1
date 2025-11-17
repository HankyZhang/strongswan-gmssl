#!/usr/bin/env pwsh
# SM2 Certificate Loading Test - English Version

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " strongSwan + GmSSL SM2 Integration Test" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Clean up old container
Write-Host "`n[1/6] Cleaning up old container..." -ForegroundColor Yellow
docker rm -f strongswan-gmsm 2>$null
Start-Sleep -Seconds 1

# 2. Start new container with --privileged
Write-Host "[2/6] Starting new container (--privileged mode)..." -ForegroundColor Yellow
docker run -d --name strongswan-gmsm --privileged strongswan-gmssl:latest /start.sh
Start-Sleep -Seconds 6

# 3. Check charon process
Write-Host "[3/6] Checking charon process..." -ForegroundColor Yellow
$charonProc = docker exec strongswan-gmsm ps aux | Select-String "charon"
if ($charonProc) {
    Write-Host "OK: charon process is running" -ForegroundColor Green
    Write-Host $charonProc
} else {
    Write-Host "ERROR: charon process not found!" -ForegroundColor Red
    docker logs strongswan-gmsm --tail 50
    exit 1
}

# 4. List algorithms
Write-Host "`n[4/6] Listing Chinese national crypto algorithms..." -ForegroundColor Yellow
$algs = docker exec strongswan-gmsm swanctl --list-algs | Select-String -Pattern "SM|sm"
if ($algs) {
    Write-Host "OK: National crypto algorithms loaded:" -ForegroundColor Green
    $algs | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
} else {
    Write-Host "ERROR: National crypto algorithms not found!" -ForegroundColor Red
    exit 1
}

# 5. Load credentials (KEY TEST)
Write-Host "`n[5/6] Loading SM2 certificates (encrypted key test)..." -ForegroundColor Yellow
$loadOutput = docker exec strongswan-gmsm swanctl --load-creds 2>&1
Write-Host $loadOutput

if ($loadOutput -match "undefined symbol") {
    Write-Host "ERROR: Undefined symbol - GmSSL build issue" -ForegroundColor Red
    exit 1
} elseif ($loadOutput -match "parsing.*private.*failed") {
    Write-Host "ERROR: Private key parsing failed" -ForegroundColor Red
    Write-Host "Check if encrypted key decryption is working" -ForegroundColor Yellow
} elseif ($loadOutput -match "encrypted PKCS#8 PEM decrypted successfully") {
    Write-Host "SUCCESS: Encrypted SM2 private key decrypted!" -ForegroundColor Green
} else {
    Write-Host "WARN: Certificate load command completed, check details above" -ForegroundColor Yellow
}

# 6. List certificates
Write-Host "`n[6/6] Listing loaded certificates..." -ForegroundColor Yellow
$certs = docker exec strongswan-gmsm swanctl --list-certs 2>&1
Write-Host $certs

if ($certs -match "subject:") {
    $certCount = ($certs | Select-String "subject:" | Measure-Object).Count
    Write-Host "`nSUCCESS: $certCount certificates loaded" -ForegroundColor Green
} else {
    Write-Host "`nWARN: No certificates found in listing" -ForegroundColor Yellow
}

# Summary
Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " Test Complete" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Write-Host "`nTo view detailed logs:" -ForegroundColor Gray
Write-Host "  docker logs strongswan-gmsm --tail 100" -ForegroundColor Gray
Write-Host "  docker exec strongswan-gmsm cat /var/log/charon.log" -ForegroundColor Gray
