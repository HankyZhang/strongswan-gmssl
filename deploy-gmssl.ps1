# ==============================================================================
# strongSwan + GmSSL 快速部署脚本 (Windows)
# 用途：一键部署国密算法版本的 VPN
# ==============================================================================

$CloudIP = "101.126.148.5"
$CloudUser = "root"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan + GmSSL 快速部署向导" -ForegroundColor Cyan
Write-Host "  支持国密算法: SM2/SM3/SM4" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 获取本地公网IP
Write-Host "[1/5] 检测本地公网IP..." -ForegroundColor Yellow
try {
    $LocalIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
    Write-Host "      ✅ 本地公网IP: $LocalIP" -ForegroundColor Green
} catch {
    Write-Host "      ⚠️  无法自动检测" -ForegroundColor Yellow
    $LocalIP = Read-Host "      请输入本地公网IP"
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  配置信息" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  云主机: $CloudIP (CentOS 7)" -ForegroundColor White
Write-Host "  本地IP: $LocalIP (Docker)" -ForegroundColor White
Write-Host "  算法: SM2/SM3/SM4 + AES/SHA2 (混合)" -ForegroundColor White
Write-Host "  网段: 10.1.0.0/24 ↔ 10.2.0.0/24" -ForegroundColor White
Write-Host ""

# 选择部署方式
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  选择部署方式" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 完整部署（云端 + 本地）" -ForegroundColor White
Write-Host "2. 仅云端部署" -ForegroundColor White
Write-Host "3. 仅本地部署" -ForegroundColor White
Write-Host ""
$choice = Read-Host "请选择 (1-3)"

# 云端部署
if ($choice -eq "1" -or $choice -eq "2") {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  [2/5] 云端部署" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "准备上传配置脚本到云主机..." -ForegroundColor Yellow
    Write-Host "⚠️  需要输入SSH密码" -ForegroundColor Yellow
    Write-Host ""
    
    # 上传脚本
    $scriptPath = "C:\Code\strongswan\cloud-vpn-setup-gmssl.sh"
    if (-not (Test-Path $scriptPath)) {
        Write-Host "❌ 错误: 未找到配置脚本 $scriptPath" -ForegroundColor Red
        exit 1
    }
    
    scp -o StrictHostKeyChecking=no $scriptPath "${CloudUser}@${CloudIP}:/tmp/vpn-setup-gmssl.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 脚本上传成功" -ForegroundColor Green
        Write-Host ""
        Write-Host "执行云端配置（需要 5-10 分钟）..." -ForegroundColor Yellow
        Write-Host ""
        
        # 执行配置
        ssh -o StrictHostKeyChecking=no "${CloudUser}@${CloudIP}" "chmod +x /tmp/vpn-setup-gmssl.sh; bash /tmp/vpn-setup-gmssl.sh"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "✅ 云端配置完成！" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "⚠️  云端配置可能有错误，请查看输出" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ 脚本上传失败" -ForegroundColor Red
        exit 1
    }
}

# 本地部署
if ($choice -eq "1" -or $choice -eq "3") {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  [3/5] 本地部署" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 检查 Docker
    Write-Host "检查 Docker..." -ForegroundColor Yellow
    $dockerVersion = docker --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker 未安装或未运行" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ $dockerVersion" -ForegroundColor Green
    Write-Host ""
    
    # 构建镜像
    Write-Host "构建 GmSSL 版本镜像..." -ForegroundColor Yellow
    Write-Host "这可能需要 10-20 分钟，请耐心等待..." -ForegroundColor White
    Write-Host ""
    
    docker-compose -f docker-compose.gmssl.yml build
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ 镜像构建成功" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "❌ 镜像构建失败" -ForegroundColor Red
        exit 1
    }
    
    # 停止旧容器
    Write-Host ""
    Write-Host "停止旧容器..." -ForegroundColor Yellow
    docker rm -f strongswan-gmssl 2>$null
    
    # 启动容器
    Write-Host "启动 strongSwan + GmSSL 容器..." -ForegroundColor Yellow
    docker-compose -f docker-compose.gmssl.yml up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 容器启动成功" -ForegroundColor Green
        
        # 等待容器启动
        Start-Sleep -Seconds 5
        
        # 加载配置
        Write-Host ""
        Write-Host "加载 VPN 配置..." -ForegroundColor Yellow
        
        # 复制国密配置文件
        Copy-Item "config\swanctl\swanctl-gmssl.conf" "config\swanctl\swanctl.conf" -Force
        
        # 重启容器以加载新配置
        docker-compose -f docker-compose.gmssl.yml restart
        Start-Sleep -Seconds 3
        
        docker exec strongswan-gmssl swanctl --load-all
        
        Write-Host "✅ 配置加载完成" -ForegroundColor Green
    } else {
        Write-Host "❌ 容器启动失败" -ForegroundColor Red
        exit 1
    }
}

# 测试连接
if ($choice -eq "1") {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  [4/5] 测试 VPN 连接" -ForegroundColor Yellow
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "发起 VPN 连接..." -ForegroundColor Yellow
    docker exec strongswan-gmssl swanctl --initiate --child cloud-net-gm
    
    Write-Host ""
    Write-Host "查看连接状态..." -ForegroundColor Yellow
    docker exec strongswan-gmssl swanctl --list-sas
}

# 完成
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  ✅ 部署完成！" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 常用命令：" -ForegroundColor Cyan
Write-Host ""
Write-Host "查看容器日志：" -ForegroundColor White
Write-Host "  docker-compose -f docker-compose.gmssl.yml logs -f" -ForegroundColor Cyan
Write-Host ""
Write-Host "查看连接状态：" -ForegroundColor White
Write-Host "  docker exec strongswan-gmssl swanctl --list-sas" -ForegroundColor Cyan
Write-Host ""
Write-Host "发起连接：" -ForegroundColor White
Write-Host "  docker exec strongswan-gmssl swanctl --initiate --child cloud-net-gm" -ForegroundColor Cyan
Write-Host ""
Write-Host "进入容器：" -ForegroundColor White
Write-Host "  docker exec -it strongswan-gmssl bash" -ForegroundColor Cyan
Write-Host ""
Write-Host "📚 详细文档：GmSSL部署指南.md" -ForegroundColor Yellow
Write-Host ""

# 打开文档
$openDoc = Read-Host "是否打开部署指南? (y/n)"
if ($openDoc -eq "y" -or $openDoc -eq "Y") {
    code "C:\Code\strongswan\GmSSL部署指南.md"
}
