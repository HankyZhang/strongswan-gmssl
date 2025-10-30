#!/bin/bash
# ==============================================================================
# strongSwan + GmSSL 云主机配置脚本 - CentOS 7 版本
# 集成国密算法 (SM2/SM3/SM4)
# 本地公网IP: 4.149.0.195
# 云主机IP: 101.126.148.5
# ==============================================================================

set -e
echo '==================================================================='
echo '  strongSwan + GmSSL 云主机自动配置 (CentOS 7)'
echo '  支持国密算法: SM2/SM3/SM4'
echo '==================================================================='

# 配置变量
STRONGSWAN_REPO="https://github.com/HankyZhang/strongswan-gmssl.git"
GMSSL_VERSION="3.1.1"
STRONGSWAN_BRANCH="master"
INSTALL_PREFIX="/usr/local"

# 1. 安装依赖
echo '[1/6] 安装依赖包...'
yum install -y gcc make gmp-devel libcap-ng-devel \
    openssl-devel pam-devel systemd-devel \
    libcurl-devel wget tar gettext git \
    iptables net-tools vim autoconf automake libtool

# 2. 编译安装 GmSSL
echo '[2/6] 编译安装 GmSSL ${GMSSL_VERSION}...'
cd /tmp

# 下载 GmSSL
if [ ! -d "GmSSL-${GMSSL_VERSION}" ]; then
    wget -q https://github.com/guanzhi/GmSSL/archive/refs/tags/v${GMSSL_VERSION}.tar.gz \
        -O gmssl-${GMSSL_VERSION}.tar.gz
    tar -zxf gmssl-${GMSSL_VERSION}.tar.gz
fi

cd GmSSL-${GMSSL_VERSION}

# 编译 GmSSL
mkdir -p build
cd build
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
      -DCMAKE_BUILD_TYPE=Release \
      -DENABLE_SM2_PRIVATE=ON \
      -DENABLE_SM3=ON \
      -DENABLE_SM4=ON \
      ..
make -j $(nproc)
make install

# 更新动态链接库缓存
echo "${INSTALL_PREFIX}/lib" > /etc/ld.so.conf.d/gmssl.conf
ldconfig

echo '✅ GmSSL 安装完成'
gmssl version

# 3. 克隆 strongSwan 仓库
echo '[3/6] 克隆 strongSwan 仓库...'
cd /tmp

if [ -d "strongswan-gmssl" ]; then
    rm -rf strongswan-gmssl
fi

git clone --depth 1 --branch ${STRONGSWAN_BRANCH} ${STRONGSWAN_REPO} strongswan-gmssl
cd strongswan-gmssl

# 4. 编译 strongSwan with GmSSL
echo '[4/6] 编译 strongSwan (集成 GmSSL)...'

# 如果有 autogen.sh，先运行
if [ -f "autogen.sh" ]; then
    ./autogen.sh
fi

# 配置编译选项
./configure --prefix=${INSTALL_PREFIX}/strongswan \
    --sysconfdir=/etc \
    --enable-eap-identity \
    --enable-eap-md5 \
    --enable-eap-mschapv2 \
    --enable-eap-tls \
    --enable-dhcp \
    --enable-openssl \
    --enable-swanctl \
    --enable-vici \
    --enable-kernel-netlink \
    --enable-gmsm \
    --with-gmssl=${INSTALL_PREFIX} \
    --disable-gmp \
    PKG_CONFIG_PATH=${INSTALL_PREFIX}/lib/pkgconfig

make -j $(nproc)
make install

echo '✅ strongSwan 编译安装完成'

# 5. 配置环境
echo '[5/6] 配置系统环境...'

# 添加到 PATH
cat > /etc/profile.d/strongswan.sh <<'EOF'
export PATH="${INSTALL_PREFIX}/strongswan/bin:${INSTALL_PREFIX}/strongswan/sbin:$PATH"
export LD_LIBRARY_PATH="${INSTALL_PREFIX}/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:$PKG_CONFIG_PATH"
EOF

source /etc/profile.d/strongswan.sh

# 创建配置目录
mkdir -p /etc/swanctl/{x509,x509ca,x509sm2,private,rsa,sm2,conf.d}
chmod 700 /etc/swanctl/private
chmod 700 /etc/swanctl/sm2

# 系统参数配置
cat >> /etc/sysctl.conf <<'SYSEOF'
# strongSwan VPN 配置
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
SYSEOF

sysctl -p > /dev/null

# 配置防火墙
echo '配置防火墙规则...'

# 停止 firewalld
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

# 使用 iptables
systemctl enable iptables 2>/dev/null || true
systemctl start iptables 2>/dev/null || true

# 配置 NAT
iptables -t nat -C POSTROUTING -s 10.2.0.0/24 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -s 10.2.0.0/24 -j MASQUERADE

# 允许 VPN 端口
iptables -C INPUT -p udp --dport 500 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p udp --dport 500 -j ACCEPT

iptables -C INPUT -p udp --dport 4500 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p udp --dport 4500 -j ACCEPT

# 保存规则
service iptables save 2>/dev/null || true

echo '✅ 系统配置完成'

# 6. 创建 VPN 配置文件（支持国密算法）
echo '[6/6] 创建 VPN 配置（国密算法）...'

cat > /etc/swanctl/swanctl.conf <<'VPNEOF'
connections {
    cloud-to-site-gm {
        version = 2
        local_addrs = 101.126.148.5
        remote_addrs = 4.149.0.195
        
        local {
            auth = psk
            id = cloud-server-gm
        }
        
        remote {
            auth = psk
            id = site-vpn-gm
        }
        
        children {
            cloud-net-gm {
                local_ts = 10.2.0.0/24
                remote_ts = 10.1.0.0/24
                # 使用国密算法组合: SM4-GCM + SM3
                esp_proposals = sm4gcm128-sm3-modp2048
                start_action = start
                dpd_action = restart
            }
        }
        
        # IKE 提案：支持国密算法
        proposals = sm4cbc-sm3-sm2,aes256-sha256-modp2048
    }
    
    # 备用连接：传统算法
    cloud-to-site-legacy {
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
            cloud-net-legacy {
                local_ts = 10.2.0.0/24
                remote_ts = 10.1.0.0/24
                esp_proposals = aes256-sha256-modp2048
                start_action = none
                dpd_action = restart
            }
        }
        
        proposals = aes256-sha256-modp2048
    }
}

secrets {
    ike-cloud-gm {
        id-cloud = cloud-server-gm
        id-site = site-vpn-gm
        secret = "MyStrongPSK2024!@#SecureVPN"
    }
    
    ike-cloud-legacy {
        id-cloud = cloud-server
        id-site = site-vpn
        secret = "MyStrongPSK2024!@#SecureVPN"
    }
}
VPNEOF

echo '✅ VPN 配置文件已创建'

# 7. 验证安装
echo ''
echo '==================================================================='
echo '  验证安装'
echo '==================================================================='

# 检查 GmSSL
echo "GmSSL 版本:"
gmssl version

# 检查 strongSwan
echo ""
echo "strongSwan 版本:"
${INSTALL_PREFIX}/strongswan/sbin/charon --version | head -5

# 检查插件
echo ""
echo "已加载插件:"
${INSTALL_PREFIX}/strongswan/sbin/charon --version | grep -A 20 "loaded plugins"

# 8. 启动 strongSwan
echo ''
echo '启动 strongSwan...'
${INSTALL_PREFIX}/strongswan/libexec/ipsec/charon &
sleep 3

# 9. 加载配置
echo '加载 VPN 配置...'
${INSTALL_PREFIX}/strongswan/sbin/swanctl --load-all

# 10. 显示状态
echo ''
echo '==================================================================='
echo '  ✅ 配置完成！VPN 状态：'
echo '==================================================================='
${INSTALL_PREFIX}/strongswan/sbin/swanctl --list-conns
echo ''
${INSTALL_PREFIX}/strongswan/sbin/swanctl --list-sas

# 清理
cd /
rm -rf /tmp/strongswan-gmssl /tmp/GmSSL-${GMSSL_VERSION} /tmp/gmssl-${GMSSL_VERSION}.tar.gz

echo ''
echo '==================================================================='
echo '  配置信息：'
echo '  - 操作系统: CentOS 7'
echo '  - GmSSL 版本: ${GMSSL_VERSION}'
echo '  - strongSwan: 从 GitHub 仓库编译'
echo '  - 支持算法: SM2/SM3/SM4 + 传统算法'
echo '  - 云端网段: 10.2.0.0/24'
echo '  - 本地网段: 10.1.0.0/24'
echo '  - PSK密钥: MyStrongPSK2024!@#SecureVPN'
echo ''
echo '  下一步：在本地执行连接命令'
echo '==================================================================='
