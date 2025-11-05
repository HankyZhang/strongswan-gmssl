#!/usr/bin/env pwsh
# Verify strongSwan + GmSSL Docker build

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan + GmSSL Build Verification" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$IMAGE = "strongswan-gmssl:3.1.1"

# Check if image exists
Write-Host "1. Checking Docker image..." -ForegroundColor Yellow
$imageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "^$IMAGE$"
if ($imageExists) {
    Write-Host "   ✓ Image found: $IMAGE" -ForegroundColor Green
} else {
    Write-Host "   ✗ Image not found: $IMAGE" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check GmSSL version
Write-Host "2. Checking GmSSL version..." -ForegroundColor Yellow
$gmssl_version = docker run --rm $IMAGE gmssl version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ GmSSL: $gmssl_version" -ForegroundColor Green
} else {
    Write-Host "   ✗ GmSSL not found" -ForegroundColor Red
}
Write-Host ""

# Check GmSSL library
Write-Host "3. Checking GmSSL library..." -ForegroundColor Yellow
$gmssl_lib = docker run --rm $IMAGE ls -lh /usr/local/lib/libgmssl.so.3.1 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ $gmssl_lib" -ForegroundColor Green
} else {
    Write-Host "   ✗ Library not found" -ForegroundColor Red
}
Write-Host ""

# Check strongSwan charon
Write-Host "4. Checking strongSwan installation..." -ForegroundColor Yellow
$charon = docker run --rm $IMAGE ls -lh /usr/local/strongswan/libexec/ipsec/charon 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Charon: $charon" -ForegroundColor Green
} else {
    Write-Host "   ✗ Charon not found" -ForegroundColor Red
}
Write-Host ""

# Check gmsm plugin
Write-Host "5. Checking gmsm plugin..." -ForegroundColor Yellow
$gmsm_plugin = docker run --rm $IMAGE ls -lh /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ Plugin: $gmsm_plugin" -ForegroundColor Green
} else {
    Write-Host "   ✗ Plugin not found" -ForegroundColor Red
}
Write-Host ""

# Check plugin linkage
Write-Host "6. Checking plugin linkage to GmSSL..." -ForegroundColor Yellow
$linkage = docker run --rm $IMAGE ldd /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so 2>&1 | Select-String "gmssl"
if ($linkage) {
    Write-Host "   ✓ Linked: $linkage" -ForegroundColor Green
} else {
    Write-Host "   ✗ Not linked to GmSSL" -ForegroundColor Red
}
Write-Host ""

# Check available plugins
Write-Host "7. Listing all strongSwan plugins..." -ForegroundColor Yellow
$plugins = docker run --rm $IMAGE ls /usr/local/strongswan/lib/ipsec/plugins/*.so 2>&1 | ForEach-Object { 
    Split-Path $_ -Leaf 
} | Where-Object { $_ -match "^libstrongswan-.*\.so$" }
$plugins | ForEach-Object {
    $pluginName = $_ -replace "^libstrongswan-", "" -replace "\.so$", ""
    if ($pluginName -eq "gmsm") {
        Write-Host "   • $pluginName (国密插件)" -ForegroundColor Green
    } else {
        Write-Host "   • $pluginName" -ForegroundColor Gray
    }
}
Write-Host ""

# Summary
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "  Build Verification Complete!" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Image Size: " -NoNewline
docker images $IMAGE --format "{{.Size}}" | Write-Host -ForegroundColor Yellow
Write-Host "Created: " -NoNewline
docker images $IMAGE --format "{{.CreatedAt}}" | Write-Host -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run container: docker run -it $IMAGE bash" -ForegroundColor White
Write-Host "  2. Test GmSSL SM2: gmssl sm2keygen -pass 1234 -out sm2.pem" -ForegroundColor White
Write-Host "  3. Test strongSwan: /usr/local/strongswan/libexec/ipsec/charon --version" -ForegroundColor White
Write-Host ""
