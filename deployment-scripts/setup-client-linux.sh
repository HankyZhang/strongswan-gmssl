#!/bin/bash
# 在 Linux 服务器上准备 strongSwan 客户端环境
# 使用方法：将此脚本上传到客户端服务器并执行

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

function info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

function error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    error "请使用 root 用户运行此脚本"
fi

info "=== strongSwan GMSM 客户端环境准备 ==="

# 1. 检查 Docker
info "检查 Docker..."
if ! command -v docker &> /dev/null; then
    warn "Docker 未安装，正在安装..."
    
    # 检测系统
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    fi
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y docker.io docker-compose
            systemctl start docker
            systemctl enable docker
            ;;
        centos|rhel)
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
            systemctl start docker
            systemctl enable docker
            ;;
        *)
            error "不支持的操作系统: $OS"
            ;;
    esac
else
    info "Docker 已安装: $(docker --version)"
fi

# 2. 创建配置目录
info "创建配置目录..."
mkdir -p /etc/strongswan-docker/swanctl/{conf.d,x509,x509ca,private,rsa}
mkdir -p /var/log/strongswan-client
chmod 755 /etc/strongswan-docker
chmod 755 /var/log/strongswan-client

# 3. 检查镜像
info "检查 Docker 镜像..."
if docker images | grep -q "strongswan-gmssl.*3.1.1"; then
    info "镜像已存在"
else
    warn "镜像不存在！"
    warn "请在 Windows 主机上执行以下命令："
    echo ""
    echo "  # 1. 导出镜像"
    echo "  docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar"
    echo ""
    echo "  # 2. 上传到此服务器"
    echo "  scp strongswan-gmssl.tar root@$(hostname -I | awk '{print $1}'):/tmp/"
    echo ""
    echo "然后在此服务器上执行："
    echo "  docker load -i /tmp/strongswan-gmssl.tar"
    echo ""
    read -p "是否现在等待镜像上传？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "等待镜像文件 /tmp/strongswan-gmssl.tar ..."
        while [ ! -f /tmp/strongswan-gmssl.tar ]; do
            sleep 2
        done
        info "发现镜像文件，正在加载..."
        docker load -i /tmp/strongswan-gmssl.tar
        info "镜像加载完成"
    fi
fi

# 4. 检查配置文件
info "检查配置文件..."
if [ ! -f /etc/strongswan-docker/swanctl/swanctl.conf ]; then
    warn "配置文件不存在，创建示例配置..."
    
    cat > /etc/strongswan-docker/swanctl/swanctl.conf <<'EOF'
connections {
    gmsm-vpn {
        version = 2
        proposals = aes256-sha256-modp2048
        remote_addrs = 101.126.148.5
        
        local {
            auth = psk
            id = vpn-client@test.com
        }
        
        remote {
            auth = psk
            id = vpn-server@test.com
        }
        
        children {
            gmsm-net {
                remote_ts = 0.0.0.0/0
                esp_proposals = aes256-sha256
                mode = tunnel
                start_action = none
                dpd_action = restart
                close_action = restart
            }
        }
    }
}

secrets {
    ike-psk {
        id-client = vpn-client@test.com
        id-server = vpn-server@test.com
        secret = "GmSM_VPN_Test_2025"
    }
}
EOF
    
    info "示例配置已创建: /etc/strongswan-docker/swanctl/swanctl.conf"
    warn "请根据实际情况修改 remote_addrs 和密码！"
fi

# 5. 配置防火墙（如果需要）
info "检查防火墙..."
if command -v firewall-cmd &> /dev/null; then
    info "配置 firewalld..."
    firewall-cmd --permanent --add-port=500/udp
    firewall-cmd --permanent --add-port=4500/udp
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    info "配置 ufw..."
    ufw allow 500/udp
    ufw allow 4500/udp
else
    warn "未检测到防火墙管理工具"
fi

# 6. 启用 IP 转发
info "启用 IP 转发..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-strongswan.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.d/99-strongswan.conf
sysctl -p /etc/sysctl.d/99-strongswan.conf

# 7. 停止可能冲突的容器
if docker ps -a | grep -q strongswan-client; then
    warn "发现已存在的 strongswan-client 容器，正在删除..."
    docker stop strongswan-client 2>/dev/null || true
    docker rm strongswan-client 2>/dev/null || true
fi

# 8. 启动客户端容器
info "启动 strongSwan 客户端容器..."
docker run -d \
  --name strongswan-client \
  --privileged \
  --network host \
  --restart unless-stopped \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /var/log/strongswan-client:/var/log/strongswan \
  -e GMSSL_ENABLED=1 \
  -e TZ=Asia/Shanghai \
  strongswan-gmssl:3.1.1

# 等待容器启动
sleep 5

# 9. 验证
info "验证容器状态..."
if docker ps | grep -q strongswan-client; then
    info "✅ 容器运行正常"
    
    info "检查插件加载..."
    docker exec strongswan-client swanctl --stats | grep -i "loaded plugins" || warn "无法获取插件信息"
    
    info "检查监听端口..."
    docker exec strongswan-client netstat -uln | grep -E "500|4500" || warn "未检测到监听端口"
    
    info "加载配置..."
    docker exec strongswan-client swanctl --load-all
    
    info "查看连接定义..."
    docker exec strongswan-client swanctl --list-conns
    
else
    error "容器启动失败"
fi

# 10. 显示摘要
info ""
info "=== 环境准备完成 ==="
info ""
info "容器名称: strongswan-client"
info "配置目录: /etc/strongswan-docker/swanctl"
info "日志目录: /var/log/strongswan-client"
info ""
info "常用命令："
info "  查看日志: docker logs -f strongswan-client"
info "  加载配置: docker exec strongswan-client swanctl --load-all"
info "  发起连接: docker exec strongswan-client swanctl --initiate --child gmsm-net"
info "  查看状态: docker exec strongswan-client swanctl --list-sas"
info "  终止连接: docker exec strongswan-client swanctl --terminate --ike gmsm-vpn"
info ""
info "测试步骤："
info "  1. 确认服务器端已启动"
info "  2. 执行: docker exec strongswan-client swanctl --initiate --child gmsm-net"
info "  3. 检查: docker exec strongswan-client swanctl --list-sas"
info "  4. 测试: docker exec strongswan-client ping 10.10.10.1"
info ""

# 创建快速测试脚本
cat > /root/test-vpn.sh <<'EOF'
#!/bin/bash
# 快速 VPN 测试脚本

echo "=== 终止旧连接 ==="
docker exec strongswan-client swanctl --terminate --ike gmsm-vpn

sleep 2

echo ""
echo "=== 发起新连接 ==="
docker exec strongswan-client swanctl --initiate --child gmsm-net

sleep 3

echo ""
echo "=== 查看连接状态 ==="
docker exec strongswan-client swanctl --list-sas

echo ""
echo "=== 测试连通性 ==="
docker exec strongswan-client ping -c 4 10.10.10.1
EOF

chmod +x /root/test-vpn.sh
info "快速测试脚本已创建: /root/test-vpn.sh"

info ""
info "现在可以运行: /root/test-vpn.sh 进行测试"
