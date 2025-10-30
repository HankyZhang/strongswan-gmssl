#!/bin/bash
#==============================================================================
# strongSwan VPN 云主机快速配置脚本
# 用途：在云主机上安装并配置 strongSwan 5.9.6
# 运行：chmod +x cloud-setup-quick.sh && ./cloud-setup-quick.sh
#==============================================================================

set -e

echo "==================================================================="
echo "  strongSwan VPN 云主机配置 (Ubuntu)"
echo "==================================================================="

# 配置变量
STRONGSWAN_VERSION="5.9.6"
LOCAL_IP="101.126.148.5"         # 云主机公网IP
LOCAL_SUBNET="10.2.0.0/24"       # 云主机虚拟网段
REMOTE_IP="YOUR_PUBLIC_IP"       # 本地公网IP（需要替换）
REMOTE_SUBNET="10.1.0.0/24"      # 本地虚拟网段
PSK="YOUR_STRONG_PSK_KEY"        # 预共享密钥（需要替换）

echo ""
echo "📝 配置参数："
echo "  本机IP: $LOCAL_IP"
echo "  本机网段: $LOCAL_SUBNET"
echo "  远程IP: $REMOTE_IP (请确认)"
echo "  远程网段: $REMOTE_SUBNET"
echo ""

# 1. 检测系统
echo "[1/7] 检测系统..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  系统: $NAME $VERSION"
else
    echo "❌ 无法识别系统版本"
    exit 1
fi

# 2. 更新系统并安装依赖
echo "[2/7] 更新系统并安装依赖..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    build-essential libpam0g-dev libssl-dev pkg-config \
    libgmp3-dev gettext wget libsystemd-dev \
    libcurl4-openssl-dev libcap-ng-dev \
    iptables iproute2 net-tools vim

# 3. 下载并编译 strongSwan
echo "[3/7] 下载并编译 strongSwan $STRONGSWAN_VERSION..."
cd /tmp
if [ ! -f strongswan-${STRONGSWAN_VERSION}.tar.gz ]; then
    wget -q https://download.strongswan.org/strongswan-${STRONGSWAN_VERSION}.tar.gz
fi
tar -zxf strongswan-${STRONGSWAN_VERSION}.tar.gz
cd strongswan-${STRONGSWAN_VERSION}

./configure --prefix=/usr/local/strongswan --sysconfdir=/etc \
    --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 \
    --enable-eap-tls --enable-dhcp --enable-openssl \
    --enable-tools --enable-swanctl --enable-vici --disable-gmp \
    > /dev/null

make -j $(nproc) > /dev/null
make install > /dev/null

echo "  ✅ strongSwan 编译安装完成"

# 4. 配置环境变量
echo "[4/7] 配置环境变量..."
cat >> /etc/profile.d/strongswan.sh <<EOF
export PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:\$PATH"
EOF
source /etc/profile.d/strongswan.sh

# 5. 创建配置目录
echo "[5/7] 创建配置目录..."
mkdir -p /etc/swanctl/{x509,x509ca,private,rsa,conf.d}
chmod 700 /etc/swanctl/private

# 6. 创建 swanctl 配置文件
echo "[6/7] 创建 VPN 配置文件..."
cat > /etc/swanctl/swanctl.conf <<EOF
# strongSwan VPN 配置 - 云主机端
connections {
    cloud-to-site {
        version = 2
        local_addrs = ${LOCAL_IP}
        remote_addrs = ${REMOTE_IP}
        
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
                local_ts = ${LOCAL_SUBNET}
                remote_ts = ${REMOTE_SUBNET}
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
        secret = "${PSK}"
    }
}
EOF

echo "  ✅ 配置文件已创建: /etc/swanctl/swanctl.conf"

# 7. 配置系统和防火墙
echo "[7/7] 配置系统和防火墙..."

# 启用 IP 转发
sysctl -w net.ipv4.ip_forward=1 > /dev/null
sysctl -w net.ipv4.conf.all.accept_redirects=0 > /dev/null
sysctl -w net.ipv4.conf.all.send_redirects=0 > /dev/null

# 持久化配置
cat >> /etc/sysctl.conf <<EOF

# strongSwan VPN 配置
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF

# 配置 iptables NAT（如果需要访问互联网）
iptables -t nat -C POSTROUTING -s ${LOCAL_SUBNET} -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s ${LOCAL_SUBNET} -j MASQUERADE

echo "  ✅ 系统配置完成"

# 清理
cd /
rm -rf /tmp/strongswan-*

echo ""
echo "==================================================================="
echo "  ✅ strongSwan 安装配置完成！"
echo "==================================================================="
echo ""
echo "📋 下一步操作："
echo ""
echo "1. 启动 strongSwan:"
echo "   /usr/local/strongswan/sbin/charon &"
echo ""
echo "2. 加载配置:"
echo "   /usr/local/strongswan/sbin/swanctl --load-all"
echo ""
echo "3. 查看连接状态:"
echo "   /usr/local/strongswan/sbin/swanctl --list-conns"
echo "   /usr/local/strongswan/sbin/swanctl --list-sas"
echo ""
echo "4. 查看日志:"
echo "   tail -f /var/log/syslog | grep charon"
echo ""
echo "⚠️  重要提醒："
echo "   1. 请在配置文件中替换 REMOTE_IP 为本地实际公网IP"
echo "   2. 请确保 PSK 密钥与本地端一致"
echo "   3. 确保云服务器安全组开放 UDP 500 和 4500 端口"
echo ""
