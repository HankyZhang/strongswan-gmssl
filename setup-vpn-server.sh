#!/bin/bash
# 远程服务器 VPN 服务端安装脚本
# 在远程服务器 (101.126.148.5) 上执行

set -e

echo "=========================================="
echo "strongSwan VPN 服务端安装"
echo "=========================================="
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "[✗] 请使用 root 用户运行此脚本"
    exit 1
fi

# 选择安装方式
echo "[?] 选择安装方式:"
echo "  1) 标准 strongSwan (apt 安装)"
echo "  2) 国密 strongSwan (编译安装)"
read -p "请选择 [1-2]: " choice

case $choice in
    1)
        echo ""
        echo "[*] 安装标准 strongSwan..."
        apt-get update
        apt-get install -y strongswan strongswan-pki strongswan-swanctl
        
        echo "[✓] strongSwan 安装完成"
        ipsec version
        ;;
        
    2)
        echo ""
        echo "[*] 安装编译依赖..."
        apt-get update
        apt-get install -y build-essential libgmp-dev libssl-dev \
            pkg-config libsystemd-dev \
            gperf bison flex \
            git cmake
        
        echo ""
        echo "[*] 编译安装 GmSSL..."
        cd /tmp
        if [ -d "GmSSL" ]; then
            rm -rf GmSSL
        fi
        git clone --depth 1 https://github.com/guanzhi/GmSSL.git
        cd GmSSL
        mkdir build && cd build
        cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
        make -j$(nproc)
        make install
        ldconfig
        
        echo "[✓] GmSSL 安装完成"
        gmssl version
        
        echo ""
        echo "[*] 编译安装 strongSwan (国密版本)..."
        cd /tmp
        if [ -d "strongswan-gmssl" ]; then
            rm -rf strongswan-gmssl
        fi
        git clone https://github.com/HankyZhang/strongswan-gmssl.git
        cd strongswan-gmssl
        
        ./autogen.sh
        ./configure --prefix=/usr --sysconfdir=/etc \
            --enable-gmsm --with-gmssl=/usr/local \
            --enable-swanctl --disable-scepclient \
            --enable-openssl --enable-systemd
        
        make -j$(nproc)
        make install
        
        echo "[✓] strongSwan (国密) 安装完成"
        ipsec version
        swanctl --version
        ;;
        
    *)
        echo "[✗] 无效选择"
        exit 1
        ;;
esac

echo ""
echo "[*] 配置系统..."

# 启用 IP 转发
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-vpn.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-vpn.conf
sysctl -p /etc/sysctl.d/99-vpn.conf

# 配置防火墙
echo ""
echo "[*] 配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw allow 500/udp
    ufw allow 4500/udp
    echo "[✓] UFW 规则已添加"
elif command -v firewalld &> /dev/null; then
    firewall-cmd --permanent --add-service=ipsec
    firewall-cmd --reload
    echo "[✓] firewalld 规则已添加"
else
    echo "[!] 请手动配置防火墙开放 UDP 500 和 4500 端口"
fi

# 创建证书目录
mkdir -p /etc/swanctl/x509
mkdir -p /etc/swanctl/x509ca
mkdir -p /etc/swanctl/private

echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo ""
echo "下一步:"
echo "  1. 将证书文件上传到 /etc/swanctl/"
echo "  2. 将配置文件上传到 /etc/swanctl/swanctl.conf"
echo "  3. 启动服务: systemctl start strongswan"
echo "  4. 查看状态: systemctl status strongswan"
echo ""
