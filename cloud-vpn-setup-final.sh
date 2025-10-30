#!/bin/bash
# ==============================================================================
# strongSwan VPN 云主机配置脚本
# 本地公网IP: 4.149.0.195
# 云主机IP: 101.126.148.5
# ==============================================================================

set -e
echo '==================================================================='
echo '  strongSwan VPN 云主机自动配置'
echo '==================================================================='

# 1. 安装依赖
export DEBIAN_FRONTEND=noninteractive
echo '[1/5] 安装依赖包...'
apt-get update -qq
apt-get install -y -qq \
    build-essential libpam0g-dev libssl-dev pkg-config \
    libgmp3-dev gettext wget libsystemd-dev \
    libcurl4-openssl-dev libcap-ng-dev \
    iptables iproute2 net-tools vim

# 2. 下载编译 strongSwan
echo '[2/5] 下载编译 strongSwan 5.9.6...'
cd /tmp
wget -q https://download.strongswan.org/strongswan-5.9.6.tar.gz
tar -zxf strongswan-5.9.6.tar.gz
cd strongswan-5.9.6

./configure --prefix=/usr/local/strongswan --sysconfdir=/etc \
    --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 \
    --enable-eap-tls --enable-dhcp --enable-openssl \
    --enable-tools --enable-swanctl --enable-vici --disable-gmp \
    --enable-kernel-netlink > /dev/null

make -j $(nproc) > /dev/null
make install > /dev/null
echo '✅ strongSwan 编译安装完成'

# 3. 配置环境
echo '[3/5] 配置环境...'
echo 'export PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:$PATH"' >> /etc/profile.d/strongswan.sh
source /etc/profile.d/strongswan.sh

mkdir -p /etc/swanctl/{x509,x509ca,private,rsa,conf.d}
chmod 700 /etc/swanctl/private

# 4. 系统参数配置
echo '[4/5] 配置系统参数...'
cat >> /etc/sysctl.conf <<'SYSEOF'
# strongSwan VPN 配置
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
SYSEOF

sysctl -p > /dev/null

# 配置防火墙 NAT
iptables -t nat -C POSTROUTING -s 10.2.0.0/24 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -j MASQUERADE

echo '✅ 系统配置完成'

# 5. 创建 VPN 配置文件
echo '[5/5] 创建 VPN 配置...'
cat > /etc/swanctl/swanctl.conf <<'VPNEOF'
connections {
    cloud-to-site {
        version = 2
        local_addrs = 101.126.148.5
        remote_addrs = 4.149.0.195
        
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

echo '✅ VPN 配置文件已创建'

# 6. 启动 strongSwan
echo ''
echo '启动 strongSwan...'
/usr/local/strongswan/sbin/charon &
sleep 3

# 7. 加载配置
echo '加载 VPN 配置...'
/usr/local/strongswan/sbin/swanctl --load-all

# 8. 显示状态
echo ''
echo '==================================================================='
echo '  ✅ 配置完成！VPN 状态：'
echo '==================================================================='
/usr/local/strongswan/sbin/swanctl --list-conns
echo ''
/usr/local/strongswan/sbin/swanctl --list-sas

# 清理
cd /
rm -rf /tmp/strongswan-*

echo ''
echo '==================================================================='
echo '  配置信息：'
echo '  - 云端网段: 10.2.0.0/24'
echo '  - 本地网段: 10.1.0.0/24'
echo '  - PSK密钥: MyStrongPSK2024!@#SecureVPN'
echo ''
echo '  下一步：在本地执行连接命令'
echo '==================================================================='
