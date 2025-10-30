#!/bin/bash
#
# strongSwan 配置文件和证书生成脚本
# 用途：快速生成完整的配置文件和证书
#
# 使用方法：
#   chmod +x generate-config.sh
#   sudo ./generate-config.sh
#

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 配置变量（根据实际情况修改）
LOCAL_GATEWAY_IP="192.168.1.1"
REMOTE_GATEWAY_IP="192.168.2.1"
LOCAL_SUBNET="10.1.0.0/16"
REMOTE_SUBNET="10.2.0.0/16"
LOCAL_ID="CN=gateway1.example.com"
REMOTE_ID="CN=gateway2.example.com"

echo ""
echo "========================================="
echo "  strongSwan 配置生成工具"
echo "========================================="
echo ""

# 1. 创建目录结构
log_info "步骤 1: 创建配置目录结构..."
mkdir -p /etc/swanctl/{x509,x509ca,private,rsa}
chmod 755 /etc/swanctl
chmod 700 /etc/swanctl/private
log_success "目录创建完成"

# 2. 生成 strongswan.conf
log_info "步骤 2: 生成 /etc/strongswan.conf..."
cat > /etc/strongswan.conf <<'EOF'
# strongswan.conf - strongSwan 全局配置

charon {
    # 日志配置
    filelog {
        /var/log/strongswan.log {
            time_format = %Y-%m-%d %H:%M:%S
            ike_name = yes
            append = no
            default = 1
            ike = 2
            cfg = 2
            knl = 2
            net = 2
        }
        stderr {
            ike = 2
            cfg = 2
        }
    }
    
    # 线程数
    threads = 16
    
    # 插件配置
    plugins {
        openssl {
            load = yes
        }
        kernel-netlink {
            load = yes
        }
        socket-default {
            load = yes
        }
        stroke {
            load = no
        }
        vici {
            load = yes
        }
        swanctl {
            load = yes
        }
    }
    
    # DNS 服务器（远程接入 VPN 使用）
    dns1 = 8.8.8.8
    dns2 = 8.8.4.4
}
EOF
log_success "strongswan.conf 生成完成"

# 3. 生成站点到站点 VPN 配置
log_info "步骤 3: 生成站点到站点 VPN 配置..."
cat > /etc/swanctl/swanctl.conf <<EOF
# swanctl.conf - 站点到站点 VPN 配置
# 
# 网关 1: $LOCAL_GATEWAY_IP (本地子网: $LOCAL_SUBNET)
# 网关 2: $REMOTE_GATEWAY_IP (远程子网: $REMOTE_SUBNET)

connections {
    site-to-site {
        # 远程网关地址
        remote_addrs = $REMOTE_GATEWAY_IP
        
        # IKE 版本（2 是推荐）
        version = 2
        
        # 本地身份配置
        local {
            auth = pubkey
            certs = gateway-cert.pem
            id = "$LOCAL_ID"
        }
        
        # 远程身份配置
        remote {
            auth = pubkey
            id = "$REMOTE_ID"
        }
        
        # 子 SA 配置（ESP 隧道）
        children {
            tunnel {
                # 本地子网
                local_ts = $LOCAL_SUBNET
                
                # 远程子网
                remote_ts = $REMOTE_SUBNET
                
                # ESP 加密提案
                # 格式：加密算法-完整性算法-DH组（PFS）
                esp_proposals = aes256gcm16-modp2048,aes256-sha256-modp2048
                
                # 启动动作
                # trap - 有流量时自动建立
                # start - 立即建立
                start_action = trap
                
                # 重密钥时间
                rekey_time = 1h
                
                # 生命周期
                life_time = 1h30m
                
                # 模式（tunnel 或 transport）
                mode = tunnel
                
                # DPD 动作
                dpd_action = restart
            }
        }
        
        # IKE SA 提案
        # 格式：加密算法-完整性算法(PRF)-DH组
        proposals = aes256gcm16-prfsha256-modp2048,aes256-sha256-modp2048
        
        # IKE SA 重密钥时间
        rekey_time = 4h
        
        # DPD（Dead Peer Detection）
        dpd_delay = 30s
        dpd_timeout = 150s
    }
}

# 私钥配置
secrets {
    private-key {
        file = gateway-key.pem
    }
}
EOF
log_success "swanctl.conf 生成完成"

# 4. 生成远程接入 VPN 配置示例
log_info "步骤 4: 生成远程接入 VPN 配置示例..."
cat > /etc/swanctl/swanctl.conf.roadwarrior <<'EOF'
# swanctl.conf - 远程接入 VPN 配置示例
# 
# 用于移动客户端接入

connections {
    roadwarrior {
        # 任意远程客户端
        remote_addrs = %any
        
        # IP 地址池
        pools = ippool
        
        version = 2
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = "vpn.example.com"
        }
        
        remote {
            auth = eap-mschapv2
            id = %any
        }
        
        children {
            rw {
                # 分配所有流量
                local_ts = 0.0.0.0/0
                
                # ESP 提案
                esp_proposals = aes256gcm16-aes128gcm16-sha256
                
                mode = tunnel
            }
        }
        
        # 不要求客户端证书
        send_certreq = no
        
        # DPD
        dpd_delay = 30s
    }
}

# IP 地址池配置
pools {
    ippool {
        addrs = 10.10.10.0/24
        dns = 8.8.8.8, 8.8.4.4
    }
}

# EAP 用户认证
secrets {
    eap-user1 {
        id = user1@example.com
        secret = "ChangeMe123!"
    }
    
    eap-user2 {
        id = user2@example.com
        secret = "SecurePass456!"
    }
}
EOF
log_success "roadwarrior 配置示例生成完成"

# 5. 生成证书
log_info "步骤 5: 生成 CA 和网关证书..."

PKI="/usr/local/strongswan/sbin/pki"

if [ ! -f "$PKI" ]; then
    log_info "PKI 工具不存在，跳过证书生成"
    log_info "请手动运行以下命令生成证书："
    cat <<'CERTEOF'

# 生成 CA 私钥和证书
pki --gen --type rsa --size 4096 --outform pem > /etc/swanctl/x509ca/ca-key.pem
pki --self --ca --lifetime 3650 \
    --in /etc/swanctl/x509ca/ca-key.pem \
    --type rsa --dn "C=CN, O=Example, CN=VPN CA" \
    --outform pem > /etc/swanctl/x509ca/ca-cert.pem

# 生成网关私钥
pki --gen --type rsa --size 2048 --outform pem > /etc/swanctl/private/gateway-key.pem

# 生成网关证书
pki --pub --in /etc/swanctl/private/gateway-key.pem --type rsa | \
pki --issue --lifetime 1825 \
    --cacert /etc/swanctl/x509ca/ca-cert.pem \
    --cakey /etc/swanctl/x509ca/ca-key.pem \
    --dn "C=CN, O=Example, CN=gateway1.example.com" \
    --san gateway1.example.com \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem > /etc/swanctl/x509/gateway-cert.pem

# 设置权限
chmod 600 /etc/swanctl/private/*
chmod 600 /etc/swanctl/x509ca/ca-key.pem
CERTEOF
else
    # 生成 CA
    if [ ! -f /etc/swanctl/x509ca/ca-cert.pem ]; then
        log_info "生成 CA 证书..."
        
        $PKI --gen --type rsa --size 4096 --outform pem > /etc/swanctl/x509ca/ca-key.pem
        
        $PKI --self --ca --lifetime 3650 \
            --in /etc/swanctl/x509ca/ca-key.pem \
            --type rsa --dn "C=CN, O=Example, CN=VPN CA" \
            --outform pem > /etc/swanctl/x509ca/ca-cert.pem
        
        chmod 600 /etc/swanctl/x509ca/ca-key.pem
        chmod 644 /etc/swanctl/x509ca/ca-cert.pem
        
        log_success "CA 证书生成完成"
    else
        log_info "CA 证书已存在，跳过"
    fi
    
    # 生成网关证书
    if [ ! -f /etc/swanctl/x509/gateway-cert.pem ]; then
        log_info "生成网关证书..."
        
        $PKI --gen --type rsa --size 2048 --outform pem > /etc/swanctl/private/gateway-key.pem
        
        $PKI --pub --in /etc/swanctl/private/gateway-key.pem --type rsa | \
        $PKI --issue --lifetime 1825 \
            --cacert /etc/swanctl/x509ca/ca-cert.pem \
            --cakey /etc/swanctl/x509ca/ca-key.pem \
            --dn "$LOCAL_ID" \
            --san "$(echo $LOCAL_ID | sed 's/CN=//')" \
            --flag serverAuth --flag ikeIntermediate \
            --outform pem > /etc/swanctl/x509/gateway-cert.pem
        
        chmod 600 /etc/swanctl/private/gateway-key.pem
        chmod 644 /etc/swanctl/x509/gateway-cert.pem
        
        log_success "网关证书生成完成"
    else
        log_info "网关证书已存在，跳过"
    fi
fi

# 6. 生成 systemd 服务文件
log_info "步骤 6: 生成 systemd 服务文件..."
cat > /etc/systemd/system/strongswan.service <<'EOF'
[Unit]
Description=strongSwan IPsec IKEv1/IKEv2 daemon using swanctl
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/local/strongswan/sbin/charon-systemd
ExecStartPost=/usr/local/strongswan/sbin/swanctl --load-all
ExecReload=/usr/local/strongswan/sbin/swanctl --load-all
Restart=on-abnormal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
log_success "systemd 服务文件生成完成"

# 7. 配置防火墙
log_info "步骤 7: 配置防火墙..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=500/udp || true
    firewall-cmd --permanent --add-port=4500/udp || true
    firewall-cmd --permanent --add-protocol=esp || true
    firewall-cmd --reload || true
    log_success "firewalld 规则已配置"
else
    log_info "firewalld 未运行，请手动配置 iptables"
fi

# 8. 配置内核参数
log_info "步骤 8: 配置内核参数..."
cat >> /etc/sysctl.conf <<'EOF'

# strongSwan IPsec VPN 配置
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
EOF

sysctl -p &> /dev/null || true
log_success "内核参数已配置"

# 总结
echo ""
echo "========================================="
echo "  配置生成完成！"
echo "========================================="
echo ""
log_success "生成的文件："
echo "  - /etc/strongswan.conf (全局配置)"
echo "  - /etc/swanctl/swanctl.conf (站点到站点 VPN)"
echo "  - /etc/swanctl/swanctl.conf.roadwarrior (远程接入示例)"
echo "  - /etc/swanctl/x509ca/ca-cert.pem (CA 证书)"
echo "  - /etc/swanctl/x509/gateway-cert.pem (网关证书)"
echo "  - /etc/swanctl/private/gateway-key.pem (网关私钥)"
echo "  - /etc/systemd/system/strongswan.service (systemd 服务)"
echo ""
log_info "下一步操作："
echo "  1. 编辑 /etc/swanctl/swanctl.conf，修改 IP 地址和子网"
echo "  2. 将 CA 证书传输到对端网关"
echo "  3. 启动服务: systemctl start strongswan"
echo "  4. 启用开机自启: systemctl enable strongswan"
echo "  5. 查看状态: swanctl --list-conns"
echo ""
