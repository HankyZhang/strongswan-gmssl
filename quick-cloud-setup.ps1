# ==============================================================================
# 一键配置云主机脚本
# 使用方法：.\quick-cloud-setup.ps1
# ==============================================================================

$CloudIP = "101.126.148.5"
$Password = "sitech#18%U"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan VPN 云主机快速配置" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. 获取本地公网IP
Write-Host "[1/4] 检测本地公网IP..." -ForegroundColor Yellow
try {
    $LocalIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).Trim()
    Write-Host "      ✅ 本地公网IP: $LocalIP" -ForegroundColor Green
} catch {
    Write-Host "      ⚠️  无法自动检测" -ForegroundColor Yellow
    $LocalIP = Read-Host "      请输入本地公网IP"
}

# 2. 显示配置信息
Write-Host ""
Write-Host "[2/4] 配置信息:" -ForegroundColor Yellow
Write-Host "      云主机: $CloudIP (10.2.0.0/24)" -ForegroundColor White
Write-Host "      本地端: $LocalIP (10.1.0.0/24)" -ForegroundColor White
Write-Host "      PSK密钥: MyStrongPSK2024!@#SecureVPN" -ForegroundColor White
Write-Host ""

# 3. 生成配置命令
Write-Host "[3/4] 生成配置命令..." -ForegroundColor Yellow

$SetupCommands = @"
#!/bin/bash
set -e
echo '=== strongSwan VPN 云主机配置 ==='

# 安装依赖
export DEBIAN_FRONTEND=noninteractive
echo '▶ 安装依赖...'
apt-get update -qq && apt-get install -y -qq build-essential libpam0g-dev libssl-dev pkg-config libgmp3-dev gettext wget libsystemd-dev libcurl4-openssl-dev libcap-ng-dev iptables iproute2 net-tools vim

# 下载编译 strongSwan
echo '▶ 编译 strongSwan...'
cd /tmp
wget -q https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6
./configure --prefix=/usr/local/strongswan --sysconfdir=/etc --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 --enable-eap-tls --enable-dhcp --enable-openssl --enable-tools --enable-swanctl --enable-vici --disable-gmp --enable-kernel-netlink > /dev/null
make -j \`$(nproc) > /dev/null && make install > /dev/null

# 配置环境
echo '▶ 配置环境...'
echo 'export PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:\`$PATH"' >> /etc/profile.d/strongswan.sh
source /etc/profile.d/strongswan.sh
mkdir -p /etc/swanctl/{x509,x509ca,private,rsa,conf.d}
chmod 700 /etc/swanctl/private

# 系统参数
cat >> /etc/sysctl.conf <<'SYSEOF'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
SYSEOF
sysctl -p > /dev/null

# 防火墙
iptables -t nat -C POSTROUTING -s 10.2.0.0/24 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -j MASQUERADE

# VPN 配置
cat > /etc/swanctl/swanctl.conf <<'VPNEOF'
connections {
    cloud-to-site {
        version = 2
        local_addrs = 101.126.148.5
        remote_addrs = $LocalIP
        
        local {
            auth = psk
            id = cloud-server
        }
        remote {
            auth = psk
            id = site-vpn
        }
        
        children {
            cloud-net {
                local_ts = 10.2.0.0/24
                remote_ts = 10.1.0.0/24
                esp_proposals = aes256-sha256-modp2048
                start_action = start
                dpd_action = restart
            }
        }
        proposals = aes256-sha256-modp2048
    }
}

secrets {
    ike-cloud {
        id-cloud = cloud-server
        id-site = site-vpn
        secret = "MyStrongPSK2024!@#SecureVPN"
    }
}
VPNEOF

# 启动
echo '▶ 启动 strongSwan...'
/usr/local/strongswan/sbin/charon &
sleep 3
/usr/local/strongswan/sbin/swanctl --load-all

echo ''
echo '✅ 配置完成！'
/usr/local/strongswan/sbin/swanctl --list-conns
/usr/local/strongswan/sbin/swanctl --list-sas

cd / && rm -rf /tmp/strongswan-*
"@

# 保存到临时文件
$TempFile = "$env:TEMP\cloud-vpn-setup.sh"
$SetupCommands | Out-File -FilePath $TempFile -Encoding ASCII -NoNewline

Write-Host "      ✅ 配置脚本已生成" -ForegroundColor Green
Write-Host ""

# 4. 显示手动操作指令
Write-Host "[4/4] 执行配置" -ForegroundColor Yellow
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  方式一：复制命令手动执行（推荐）" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. 打开新的 PowerShell 或 SSH 客户端，连接云主机：" -ForegroundColor White
Write-Host ""
Write-Host "   ssh root@$CloudIP" -ForegroundColor Cyan
Write-Host "   密码: $Password" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. 连接成功后，复制粘贴以下完整命令块：" -ForegroundColor White
Write-Host ""
Write-Host "--- 复制下方所有内容（包括 #!/bin/bash）---" -ForegroundColor Yellow
Write-Host $SetupCommands -ForegroundColor Gray
Write-Host "--- 复制结束 ---" -ForegroundColor Yellow
Write-Host ""

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  方式二：使用 SSH 自动上传执行" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "如果系统安装了 OpenSSH 客户端，可以尝试自动执行：" -ForegroundColor White
Write-Host ""

$choice = Read-Host "是否尝试自动上传并执行? (y/n)"

if ($choice -eq 'y' -or $choice -eq 'Y') {
    Write-Host ""
    Write-Host "📤 上传脚本到云主机..." -ForegroundColor Cyan
    
    # 使用 scp 上传
    & scp -o StrictHostKeyChecking=no $TempFile "root@${CloudIP}:/tmp/setup-vpn.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ 文件上传成功" -ForegroundColor Green
        Write-Host ""
        Write-Host "🚀 执行配置脚本..." -ForegroundColor Cyan
        
        # 执行脚本
        & ssh -o StrictHostKeyChecking=no "root@${CloudIP}" "chmod +x /tmp/setup-vpn.sh && /tmp/setup-vpn.sh"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "==================================================================" -ForegroundColor Green
            Write-Host "  ✅ 云主机配置成功！" -ForegroundColor Green
            Write-Host "==================================================================" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "❌ 执行失败，请使用方式一手动操作" -ForegroundColor Red
        }
    } else {
        Write-Host "❌ 文件上传失败，请使用方式一手动操作" -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "请使用方式一手动复制粘贴命令" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  下一步：测试 VPN 连接" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "云主机配置完成后，在本地执行：" -ForegroundColor White
Write-Host ""
Write-Host "1. 检查本地容器状态：" -ForegroundColor White
Write-Host "   docker-compose ps" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. 重启本地容器（加载新配置）：" -ForegroundColor White
Write-Host "   docker-compose restart vpn-server" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. 发起连接：" -ForegroundColor White
Write-Host "   docker-compose exec vpn-server swanctl --initiate --child cloud-net" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. 查看连接状态：" -ForegroundColor White
Write-Host "   docker-compose exec vpn-server swanctl --list-sas" -ForegroundColor Cyan
Write-Host ""
Write-Host "5. 测试连通性：" -ForegroundColor White
Write-Host "   docker-compose exec vpn-server ping 10.2.0.1" -ForegroundColor Cyan
Write-Host ""

# 清理临时文件
Remove-Item $TempFile -ErrorAction SilentlyContinue

Write-Host "📄 详细文档参考: 云主机配置手册.md" -ForegroundColor Yellow
Write-Host ""
