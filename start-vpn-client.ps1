# VPN 客户端启动脚本
# 使用 Docker 容器连接到 VPN 服务器

param(
    [string]$RemoteHost = "101.126.148.5",
    [switch]$UseGMAlgorithm,
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "启动 strongSwan VPN 客户端" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$certDir = Join-Path $PSScriptRoot "vpn-certs"

# 检查证书目录
if (-not (Test-Path $certDir)) {
    Write-Host "[✗] 证书目录不存在，请先运行 setup-vpn-test.ps1" -ForegroundColor Red
    exit 1
}

# 检查配置文件
if (-not (Test-Path "$certDir/swanctl.conf")) {
    Write-Host "[✗] 配置文件不存在，请先运行 setup-vpn-test.ps1 -SetupClient" -ForegroundColor Red
    exit 1
}

Write-Host "`n[*] 配置信息:" -ForegroundColor Yellow
Write-Host "  - 远程主机: $RemoteHost" -ForegroundColor White
Write-Host "  - 使用国密: $(if ($UseGMAlgorithm) { '是' } else { '否' })" -ForegroundColor White
Write-Host "  - 证书目录: $certDir" -ForegroundColor White
Write-Host ""

if ($Interactive) {
    Write-Host "[*] 启动交互式 Docker 容器..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "容器内可用命令:" -ForegroundColor Cyan
    Write-Host "  swanctl --load-all              # 加载配置" -ForegroundColor White
    Write-Host "  swanctl --initiate --child tunnel  # 启动连接" -ForegroundColor White
    Write-Host "  swanctl --list-sas              # 查看连接状态" -ForegroundColor White
    Write-Host "  swanctl --list-conns            # 查看配置" -ForegroundColor White
    Write-Host "  ip xfrm state                   # 查看 IPsec SA" -ForegroundColor White
    Write-Host "  ping <目标IP>                    # 测试连通性" -ForegroundColor White
    Write-Host ""
    
    docker run -it --rm --privileged `
        --name vpn-client `
        --network host `
        -v "${certDir}:/certs" `
        -v "${certDir}/swanctl.conf:/etc/swanctl/swanctl.conf" `
        strongswan-gmssl:3.1.1 bash
        
} else {
    Write-Host "[*] 启动 VPN 客户端容器（后台）..." -ForegroundColor Yellow
    
    $containerId = docker run -d --privileged `
        --name vpn-client `
        --network host `
        -v "${certDir}:/certs" `
        -v "${certDir}/swanctl.conf:/etc/swanctl/swanctl.conf" `
        strongswan-gmssl:3.1.1 `
        sh -c "swanctl --load-all && swanctl --initiate --child tunnel && tail -f /dev/null"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] VPN 客户端已启动 (容器 ID: $($containerId.Substring(0,12)))" -ForegroundColor Green
        
        Start-Sleep -Seconds 3
        
        Write-Host "`n[*] 检查连接状态..." -ForegroundColor Yellow
        docker exec vpn-client swanctl --list-sas
        
        Write-Host "`n可用命令:" -ForegroundColor Cyan
        Write-Host "  docker exec vpn-client swanctl --list-sas    # 查看连接" -ForegroundColor White
        Write-Host "  docker exec vpn-client ping 10.10.10.1       # 测试连通" -ForegroundColor White
        Write-Host "  docker logs -f vpn-client                    # 查看日志" -ForegroundColor White
        Write-Host "  docker stop vpn-client                       # 停止客户端" -ForegroundColor White
        Write-Host ""
        
    } else {
        Write-Host "[✗] VPN 客户端启动失败" -ForegroundColor Red
        exit 1
    }
}
