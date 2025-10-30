# ==============================================================================
# 自动化云主机配置脚本
# 使用 scp 上传并通过 SSH 执行
# ==============================================================================

$CloudIP = "101.126.148.5"
$Username = "root"
$ScriptPath = "C:\Code\strongswan\cloud-vpn-setup-final.sh"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan VPN 云主机自动配置" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "目标主机: $Username@$CloudIP" -ForegroundColor White
Write-Host "配置脚本: $ScriptPath" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  需要输入密码: sitech#18%U" -ForegroundColor Yellow
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 上传配置脚本
Write-Host "[1/3] 上传配置脚本到云主机..." -ForegroundColor Yellow
$uploadCmd = "scp -o StrictHostKeyChecking=no `"$ScriptPath`" ${Username}@${CloudIP}:/tmp/vpn-setup.sh"
Write-Host "执行: $uploadCmd" -ForegroundColor Gray

try {
    & scp -o StrictHostKeyChecking=no "$ScriptPath" "${Username}@${CloudIP}:/tmp/vpn-setup.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 脚本上传成功" -ForegroundColor Green
    } else {
        Write-Host "❌ 脚本上传失败 (退出码: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host ""
        Write-Host "请手动执行以下步骤：" -ForegroundColor Yellow
        Write-Host "1. ssh root@101.126.148.5" -ForegroundColor Cyan
        Write-Host "2. 复制 cloud-vpn-setup-final.sh 的内容并粘贴到 SSH 终端" -ForegroundColor Cyan
        exit 1
    }
} catch {
    Write-Host "❌ 上传出错: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 步骤 2: 设置执行权限并运行
Write-Host "[2/3] 执行配置脚本..." -ForegroundColor Yellow
Write-Host "这可能需要 3-5 分钟，请耐心等待..." -ForegroundColor White
Write-Host ""

$execCmd = 'chmod +x /tmp/vpn-setup.sh && /tmp/vpn-setup.sh'
Write-Host "执行: ssh ${Username}@${CloudIP} `"$execCmd`"" -ForegroundColor Gray

try {
    & ssh -o StrictHostKeyChecking=no "${Username}@${CloudIP}" "$execCmd"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ 云主机配置成功！" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "⚠️  配置脚本执行完成，但返回码为: $LASTEXITCODE" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ 执行出错: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "[3/3] 验证配置..." -ForegroundColor Yellow
Write-Host ""

# 步骤 3: 验证配置
$verifyCmd = '/usr/local/strongswan/sbin/swanctl --list-conns && echo "" && /usr/local/strongswan/sbin/swanctl --list-sas'
& ssh -o StrictHostKeyChecking=no "${Username}@${CloudIP}" "$verifyCmd"

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  ✅ 云主机配置完成！" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 下一步：在本地执行以下命令" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 重启本地容器：" -ForegroundColor White
Write-Host "   docker-compose restart vpn-server" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. 发起连接：" -ForegroundColor White
Write-Host "   docker-compose exec vpn-server swanctl --initiate --child cloud-net" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 查看连接状态：" -ForegroundColor White
Write-Host "   docker-compose exec vpn-server swanctl --list-sas" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. 测试连通性：" -ForegroundColor White
Write-Host "   docker-compose exec vpn-server ping 10.2.0.1" -ForegroundColor Cyan
Write-Host ""
