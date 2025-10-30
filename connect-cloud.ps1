# ==============================================================================
# 云主机 VPN 配置辅助脚本
# 用途：帮助连接到云主机并配置 VPN
# ==============================================================================

$CloudIP = "101.126.148.5"
$Username = "root"
$Password = "sitech#18%U"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  strongSwan VPN 云主机配置向导" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

# 检查是否安装了 SSH 客户端
$sshExists = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshExists) {
    Write-Host "❌ 未找到 SSH 客户端" -ForegroundColor Red
    Write-Host "请安装 OpenSSH 客户端或使用其他 SSH 工具（如 PuTTY）" -ForegroundColor Yellow
    exit 1
}

Write-Host "📋 配置信息：" -ForegroundColor Green
Write-Host "  云主机IP: $CloudIP"
Write-Host "  用户名: $Username"
Write-Host "  虚拟网段: 10.2.0.0/24 (云端) ↔ 10.1.0.0/24 (本地)"
Write-Host ""

# 获取本地公网IP
Write-Host "🔍 检测本地公网IP..." -ForegroundColor Yellow
try {
    $LocalPublicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -TimeoutSec 5).Trim()
    Write-Host "  检测到公网IP: $LocalPublicIP" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️  无法自动检测，请手动输入" -ForegroundColor Yellow
    $LocalPublicIP = Read-Host "请输入本地公网IP"
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  方式一：自动配置（推荐）" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "将创建并执行完整配置脚本。按任意键继续..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# 创建临时配置脚本
$TempScript = @"
#!/bin/bash
set -e
echo "=== strongSwan VPN 云主机自动配置 ==="

# 1. 安装依赖和编译 strongSwan
echo "[1/4] 安装依赖..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -y -qq build-essential libpam0g-dev libssl-dev pkg-config libgmp3-dev gettext wget libsystemd-dev libcurl4-openssl-dev libcap-ng-dev iptables iproute2 net-tools vim

echo "[2/4] 编译 strongSwan 5.9.6..."
cd /tmp
wget -q https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6
./configure --prefix=/usr/local/strongswan --sysconfdir=/etc --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 --enable-eap-tls --enable-dhcp --enable-openssl --enable-tools --enable-swanctl --enable-vici --disable-gmp --enable-kernel-netlink > /dev/null
make -j \`$(nproc) > /dev/null && make install > /dev/null

echo "[3/4] 配置系统..."
echo 'export PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:\$PATH"' >> /etc/profile.d/strongswan.sh
source /etc/profile.d/strongswan.sh
mkdir -p /etc/swanctl/{x509,x509ca,private,rsa,conf.d}
chmod 700 /etc/swanctl/private

cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sysctl -p > /dev/null

iptables -t nat -C POSTROUTING -s 10.2.0.0/24 -j MASQUERADE 2>/dev/null || iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -j MASQUERADE

echo "[4/4] 创建 VPN 配置..."
cat > /etc/swanctl/swanctl.conf <<EEOF
connections {
    cloud-to-site {
        version = 2
        local_addrs = 101.126.148.5
        remote_addrs = $LocalPublicIP
        
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
EEOF

echo "启动 strongSwan..."
/usr/local/strongswan/sbin/charon &
sleep 3
/usr/local/strongswan/sbin/swanctl --load-all

echo ""
echo "✅ 配置完成！"
/usr/local/strongswan/sbin/swanctl --list-conns
/usr/local/strongswan/sbin/swanctl --list-sas

cd / && rm -rf /tmp/strongswan-*
"@

# 保存脚本到本地
$TempScript | Out-File -FilePath "$PSScriptRoot\temp-cloud-config.sh" -Encoding ASCII -NoNewline

Write-Host "📤 上传并执行配置脚本..." -ForegroundColor Yellow
Write-Host ""
Write-Host "⚠️  需要输入密码: $Password" -ForegroundColor Yellow
Write-Host ""

# 使用 scp 上传脚本
Write-Host "上传脚本到云主机..." -ForegroundColor Cyan
& scp -o StrictHostKeyChecking=no "$PSScriptRoot\temp-cloud-config.sh" "${Username}@${CloudIP}:/tmp/setup-vpn.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 文件上传失败" -ForegroundColor Red
    exit 1
}

# 执行脚本
Write-Host ""
Write-Host "🚀 执行配置脚本..." -ForegroundColor Cyan
& ssh -o StrictHostKeyChecking=no "${Username}@${CloudIP}" "chmod +x /tmp/setup-vpn.sh && /tmp/setup-vpn.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "  ✅ 云主机配置成功！" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 下一步：测试本地连接" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. 确保本地 Docker 容器正在运行：" -ForegroundColor White
    Write-Host "   docker-compose ps" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. 进入容器并发起连接：" -ForegroundColor White
    Write-Host "   docker-compose exec vpn-server swanctl --initiate --child cloud-net" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. 查看连接状态：" -ForegroundColor White
    Write-Host "   docker-compose exec vpn-server swanctl --list-sas" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "❌ 配置失败，请检查错误信息" -ForegroundColor Red
}

# 清理临时文件
Remove-Item "$PSScriptRoot\temp-cloud-config.sh" -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  方式二：手动 SSH 连接" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "如果自动配置失败，可以手动连接：" -ForegroundColor Yellow
Write-Host ""
Write-Host "ssh ${Username}@${CloudIP}" -ForegroundColor Cyan
Write-Host "密码: $Password" -ForegroundColor Yellow
Write-Host ""
Write-Host "然后运行配置命令（参考 cloud-one-command.sh）" -ForegroundColor White
Write-Host ""
