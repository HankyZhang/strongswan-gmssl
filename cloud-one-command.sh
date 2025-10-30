#!/bin/bash
#==============================================================================
# 快速云主机配置指令 - 复制粘贴版
# 请在 SSH 连接到云主机后，逐步执行以下命令
#==============================================================================

# Step 1: 创建配置脚本
cat > /tmp/install-vpn.sh <<'SCRIPT_EOF'
#!/bin/bash
set -e

echo "==================================================================="
echo "  strongSwan VPN 云主机配置"
echo "==================================================================="

STRONGSWAN_VERSION="5.9.6"

# 1. 安装依赖
echo "[1/5] 安装依赖包..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y build-essential libpam0g-dev libssl-dev pkg-config \
    libgmp3-dev gettext wget libsystemd-dev libcurl4-openssl-dev \
    libcap-ng-dev iptables iproute2 net-tools vim

# 2. 下载编译 strongSwan
echo "[2/5] 编译 strongSwan..."
cd /tmp
wget -q https://download.strongswan.org/strongswan-${STRONGSWAN_VERSION}.tar.gz
tar -zxf strongswan-${STRONGSWAN_VERSION}.tar.gz
cd strongswan-${STRONGSWAN_VERSION}
./configure --prefix=/usr/local/strongswan --sysconfdir=/etc \
    --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 \
    --enable-eap-tls --enable-dhcp --enable-openssl \
    --enable-tools --enable-swanctl --enable-vici --disable-gmp \
    --enable-kernel-netlink > /dev/null
make -j $(nproc) > /dev/null
make install > /dev/null
echo "✅ strongSwan 安装完成"

# 3. 配置环境
echo "[3/5] 配置环境..."
echo 'export PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:$PATH"' >> /etc/profile.d/strongswan.sh
source /etc/profile.d/strongswan.sh
mkdir -p /etc/swanctl/{x509,x509ca,private,rsa,conf.d}
chmod 700 /etc/swanctl/private

# 4. 系统配置
echo "[4/5] 配置系统参数..."
cat >> /etc/sysctl.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF
sysctl -p > /dev/null

# 5. 防火墙配置（允许 VPN 端口）
echo "[5/5] 配置防火墙..."
# 如果使用 ufw
if command -v ufw &> /dev/null; then
    ufw allow 500/udp
    ufw allow 4500/udp
fi
# 配置 NAT
iptables -t nat -C POSTROUTING -s 10.2.0.0/24 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -j MASQUERADE

echo ""
echo "✅ 安装完成！"
echo ""
cd /
rm -rf /tmp/strongswan-*
SCRIPT_EOF

# Step 2: 执行安装
chmod +x /tmp/install-vpn.sh
/tmp/install-vpn.sh

# Step 3: 创建 VPN 配置（需要知道本地公网IP）
echo ""
echo "请输入本地 Docker 主机的公网IP地址："
read -p "本地公网IP: " REMOTE_IP

cat > /etc/swanctl/swanctl.conf <<EOF
connections {
    cloud-to-site {
        version = 2
        local_addrs = 101.126.148.5
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
EOF

echo "✅ VPN 配置文件已创建"

# Step 4: 启动 strongSwan
echo ""
echo "启动 strongSwan..."
/usr/local/strongswan/sbin/charon &
sleep 3

# Step 5: 加载配置
echo "加载 VPN 配置..."
/usr/local/strongswan/sbin/swanctl --load-all

# Step 6: 查看状态
echo ""
echo "==================================================================="
echo "VPN 配置状态："
echo "==================================================================="
/usr/local/strongswan/sbin/swanctl --list-conns
/usr/local/strongswan/sbin/swanctl --list-sas

echo ""
echo "✅ 云主机配置完成！等待本地连接..."
echo ""
echo "查看日志: tail -f /var/log/syslog | grep charon"
