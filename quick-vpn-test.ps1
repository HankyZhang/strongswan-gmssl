# VPN 测试快速启动脚本
# 自动化完成所有设置步骤

param(
    [string]$RemoteHost = "101.126.148.5",
    [string]$RemotePassword = "sitech#18%U",
    [switch]$UseGMAlgorithm
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "strongSwan VPN 快速测试" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 生成证书和配置
Write-Host "[步骤 1/4] 生成证书和配置文件..." -ForegroundColor Yellow
if ($UseGMAlgorithm) {
    .\setup-vpn-test.ps1 -RemoteHost $RemoteHost -UseGMAlgorithm -SetupClient -SetupServer
} else {
    .\setup-vpn-test.ps1 -RemoteHost $RemoteHost -SetupClient -SetupServer
}

Write-Host ""
Write-Host "[步骤 2/4] 传输文件到远程服务器..." -ForegroundColor Yellow
Write-Host "[!] 此步骤需要手动操作，因为涉及密码输入" -ForegroundColor Yellow
Write-Host ""
Write-Host "请在新的 PowerShell 窗口执行以下命令:" -ForegroundColor Cyan
Write-Host ""

$certDir = Join-Path $PSScriptRoot "vpn-certs"

Write-Host "# 1. 传输安装脚本" -ForegroundColor White
Write-Host "scp setup-vpn-server.sh root@${RemoteHost}:/tmp/" -ForegroundColor Gray
Write-Host ""

Write-Host "# 2. 在远程服务器上执行安装" -ForegroundColor White
Write-Host "ssh root@${RemoteHost}" -ForegroundColor Gray
Write-Host "bash /tmp/setup-vpn-server.sh" -ForegroundColor Gray
Write-Host "exit" -ForegroundColor Gray
Write-Host ""

Write-Host "# 3. 传输证书文件" -ForegroundColor White
Write-Host "scp ${certDir}/server-key.pem root@${RemoteHost}:/etc/swanctl/private/" -ForegroundColor Gray
Write-Host "scp ${certDir}/server-cert.pem root@${RemoteHost}:/etc/swanctl/x509/" -ForegroundColor Gray
Write-Host "scp ${certDir}/ca-cert.pem root@${RemoteHost}:/etc/swanctl/x509ca/" -ForegroundColor Gray
Write-Host ""

if ($UseGMAlgorithm) {
    Write-Host "# 4. 传输配置文件 (国密)" -ForegroundColor White
    Write-Host "scp ${certDir}/ipsec.conf root@${RemoteHost}:/etc/swanctl/swanctl.conf" -ForegroundColor Gray
} else {
    Write-Host "# 4. 传输配置文件 (标准)" -ForegroundColor White
    Write-Host "scp ${certDir}/ipsec.conf root@${RemoteHost}:/etc/ipsec.conf" -ForegroundColor Gray
}
Write-Host ""

Write-Host "# 5. 启动服务" -ForegroundColor White
Write-Host "ssh root@${RemoteHost} 'systemctl restart strongswan && systemctl status strongswan'" -ForegroundColor Gray
Write-Host ""

Write-Host "[?] 完成以上步骤后，按任意键继续..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "[步骤 3/4] 启动 VPN 客户端..." -ForegroundColor Yellow
if ($UseGMAlgorithm) {
    .\start-vpn-client.ps1 -RemoteHost $RemoteHost -UseGMAlgorithm -Interactive
} else {
    .\start-vpn-client.ps1 -RemoteHost $RemoteHost -Interactive
}

Write-Host ""
Write-Host "[步骤 4/4] 测试完成！" -ForegroundColor Green
Write-Host ""
