#!/bin/bash
#
# strongSwan 5.9.6 安装配置测试脚本
# 用途：验证 strongSwan 安装是否成功，配置是否正确
#
# 使用方法：
#   chmod +x test-strongswan.sh
#   sudo ./test-strongswan.sh
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 测试 1: 检查系统环境
test_system_environment() {
    log_info "测试 1: 检查系统环境"
    
    # 检查操作系统
    if [ -f /etc/redhat-release ]; then
        OS_VERSION=$(cat /etc/redhat-release)
        log_success "操作系统: $OS_VERSION"
    else
        log_warning "非 CentOS/RHEL 系统"
    fi
    
    # 检查内核版本
    KERNEL_VERSION=$(uname -r)
    log_success "内核版本: $KERNEL_VERSION"
    
    # 检查内核 IPsec 支持
    if [ -d /proc/net/xfrm ]; then
        log_success "内核支持 XFRM (IPsec)"
    else
        log_error "内核不支持 XFRM，请检查内核配置"
    fi
    
    echo ""
}

# 测试 2: 检查依赖包
test_dependencies() {
    log_info "测试 2: 检查依赖包"
    
    REQUIRED_PACKAGES=(
        "openssl"
        "openssl-devel"
        "make"
        "gcc"
    )
    
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if rpm -q "$pkg" &> /dev/null; then
            log_success "$pkg 已安装"
        else
            log_error "$pkg 未安装"
        fi
    done
    
    echo ""
}

# 测试 3: 检查 strongSwan 安装
test_strongswan_installation() {
    log_info "测试 3: 检查 strongSwan 安装"
    
    # 检查可执行文件
    if [ -f /usr/local/strongswan/sbin/ipsec ]; then
        log_success "ipsec 可执行文件存在"
        
        # 获取版本信息
        VERSION=$(/usr/local/strongswan/sbin/ipsec version)
        log_info "版本: $VERSION"
    else
        log_error "ipsec 可执行文件不存在，请先安装 strongSwan"
        exit 1
    fi
    
    # 检查 swanctl
    if [ -f /usr/local/strongswan/sbin/swanctl ]; then
        log_success "swanctl 可执行文件存在"
    else
        log_warning "swanctl 可执行文件不存在"
    fi
    
    # 检查库文件
    if [ -d /usr/local/strongswan/lib/ipsec ]; then
        PLUGIN_COUNT=$(ls -1 /usr/local/strongswan/lib/ipsec/plugins/*.so 2>/dev/null | wc -l)
        log_success "插件目录存在，共 $PLUGIN_COUNT 个插件"
    else
        log_warning "插件目录不存在"
    fi
    
    echo ""
}

# 测试 4: 检查配置文件
test_configuration_files() {
    log_info "测试 4: 检查配置文件"
    
    # 检查配置目录
    if [ -d /etc/swanctl ]; then
        log_success "/etc/swanctl 目录存在"
        
        # 检查子目录
        for dir in x509 x509ca private rsa; do
            if [ -d /etc/swanctl/$dir ]; then
                log_success "  - /etc/swanctl/$dir 存在"
            else
                log_warning "  - /etc/swanctl/$dir 不存在"
            fi
        done
    else
        log_warning "/etc/swanctl 目录不存在，需要创建"
    fi
    
    # 检查配置文件
    if [ -f /etc/swanctl/swanctl.conf ]; then
        log_success "/etc/swanctl/swanctl.conf 存在"
        
        # 验证配置文件语法
        if /usr/local/strongswan/sbin/swanctl --load-conns --noprompt 2>&1 | grep -q "loaded"; then
            log_success "配置文件语法正确"
        else
            log_warning "配置文件可能有问题"
        fi
    else
        log_warning "/etc/swanctl/swanctl.conf 不存在"
    fi
    
    # 检查 strongswan.conf
    if [ -f /etc/strongswan.conf ]; then
        log_success "/etc/strongswan.conf 存在"
    else
        log_warning "/etc/strongswan.conf 不存在"
    fi
    
    echo ""
}

# 测试 5: 检查证书
test_certificates() {
    log_info "测试 5: 检查证书"
    
    # 检查 CA 证书
    if [ -f /etc/swanctl/x509ca/ca-cert.pem ]; then
        log_success "CA 证书存在"
        
        # 验证证书
        if openssl x509 -in /etc/swanctl/x509ca/ca-cert.pem -noout -text &> /dev/null; then
            log_success "CA 证书有效"
            
            # 显示证书信息
            SUBJECT=$(openssl x509 -in /etc/swanctl/x509ca/ca-cert.pem -noout -subject | sed 's/subject=//')
            ISSUER=$(openssl x509 -in /etc/swanctl/x509ca/ca-cert.pem -noout -issuer | sed 's/issuer=//')
            EXPIRY=$(openssl x509 -in /etc/swanctl/x509ca/ca-cert.pem -noout -enddate | sed 's/notAfter=//')
            
            log_info "  主题: $SUBJECT"
            log_info "  签发者: $ISSUER"
            log_info "  过期时间: $EXPIRY"
        else
            log_error "CA 证书无效"
        fi
    else
        log_warning "CA 证书不存在"
    fi
    
    # 检查网关证书
    CERT_COUNT=$(ls -1 /etc/swanctl/x509/*.pem 2>/dev/null | wc -l)
    if [ $CERT_COUNT -gt 0 ]; then
        log_success "找到 $CERT_COUNT 个网关证书"
    else
        log_warning "未找到网关证书"
    fi
    
    # 检查私钥
    KEY_COUNT=$(ls -1 /etc/swanctl/private/*.pem 2>/dev/null | wc -l)
    if [ $KEY_COUNT -gt 0 ]; then
        log_success "找到 $KEY_COUNT 个私钥"
        
        # 检查私钥权限
        for keyfile in /etc/swanctl/private/*.pem; do
            PERMS=$(stat -c %a "$keyfile")
            if [ "$PERMS" == "600" ] || [ "$PERMS" == "400" ]; then
                log_success "  $(basename $keyfile) 权限正确 ($PERMS)"
            else
                log_warning "  $(basename $keyfile) 权限不安全 ($PERMS)，应该是 600"
            fi
        done
    else
        log_warning "未找到私钥"
    fi
    
    echo ""
}

# 测试 6: 检查网络配置
test_network_configuration() {
    log_info "测试 6: 检查网络配置"
    
    # 检查 IP 转发
    IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$IP_FORWARD" == "1" ]; then
        log_success "IP 转发已启用"
    else
        log_warning "IP 转发未启用（网关需要启用）"
    fi
    
    # 检查防火墙
    if command -v firewall-cmd &> /dev/null; then
        log_info "检查 firewalld 规则..."
        
        # 检查 UDP 500
        if firewall-cmd --list-ports 2>/dev/null | grep -q "500/udp"; then
            log_success "UDP 500 (IKE) 端口已开放"
        else
            log_warning "UDP 500 端口未开放"
        fi
        
        # 检查 UDP 4500
        if firewall-cmd --list-ports 2>/dev/null | grep -q "4500/udp"; then
            log_success "UDP 4500 (NAT-T) 端口已开放"
        else
            log_warning "UDP 4500 端口未开放"
        fi
        
        # 检查 ESP 协议
        if firewall-cmd --list-protocols 2>/dev/null | grep -q "esp"; then
            log_success "ESP 协议已允许"
        else
            log_warning "ESP 协议未允许"
        fi
    else
        log_info "firewalld 未运行，检查 iptables..."
        
        if iptables -L -n | grep -q "udp dpt:500"; then
            log_success "iptables 规则包含 UDP 500"
        else
            log_warning "iptables 未配置 UDP 500"
        fi
    fi
    
    echo ""
}

# 测试 7: 检查 strongSwan 服务状态
test_service_status() {
    log_info "测试 7: 检查 strongSwan 服务状态"
    
    # 检查进程
    if pgrep -x charon &> /dev/null; then
        log_success "charon 守护进程正在运行"
        
        # 显示进程信息
        CHARON_PID=$(pgrep -x charon)
        log_info "  PID: $CHARON_PID"
    else
        log_warning "charon 守护进程未运行"
    fi
    
    # 检查 systemd 服务
    if systemctl is-active --quiet strongswan 2>/dev/null; then
        log_success "strongswan systemd 服务正在运行"
    else
        log_info "systemd 服务未配置或未运行"
    fi
    
    # 检查端口监听
    if netstat -uln 2>/dev/null | grep -q ":500 "; then
        log_success "UDP 500 端口正在监听"
    else
        log_warning "UDP 500 端口未监听"
    fi
    
    if netstat -uln 2>/dev/null | grep -q ":4500 "; then
        log_success "UDP 4500 端口正在监听"
    else
        log_info "UDP 4500 端口未监听（仅 NAT-T 需要）"
    fi
    
    echo ""
}

# 测试 8: 检查日志
test_logs() {
    log_info "测试 8: 检查日志"
    
    # 检查日志文件
    if [ -f /var/log/strongswan.log ]; then
        log_success "日志文件存在: /var/log/strongswan.log"
        
        # 检查最近的错误
        ERROR_COUNT=$(grep -i "error" /var/log/strongswan.log | tail -10 | wc -l)
        if [ $ERROR_COUNT -gt 0 ]; then
            log_warning "最近有 $ERROR_COUNT 条错误日志"
            log_info "最近的错误："
            grep -i "error" /var/log/strongswan.log | tail -5
        else
            log_success "没有最近的错误日志"
        fi
    else
        log_info "日志文件不存在（可能配置到其他位置）"
    fi
    
    # 检查 systemd 日志
    if command -v journalctl &> /dev/null; then
        if journalctl -u strongswan --no-pager -n 1 &> /dev/null; then
            log_success "systemd 日志可访问"
        fi
    fi
    
    echo ""
}

# 测试 9: 测试加密算法
test_crypto_algorithms() {
    log_info "测试 9: 测试加密算法"
    
    # 测试 OpenSSL
    if /usr/local/strongswan/sbin/ipsec listplugins 2>/dev/null | grep -q "openssl"; then
        log_success "OpenSSL 插件已加载"
        
        # 列出支持的算法
        log_info "支持的加密算法："
        /usr/local/strongswan/sbin/ipsec listalgs 2>/dev/null | grep -A 5 "encryption:" || log_warning "无法列出算法"
    else
        log_warning "OpenSSL 插件未加载"
    fi
    
    echo ""
}

# 测试 10: 连接配置测试
test_connection_config() {
    log_info "测试 10: 连接配置测试"
    
    if [ -f /etc/swanctl/swanctl.conf ]; then
        # 列出配置的连接
        CONNS=$(/usr/local/strongswan/sbin/swanctl --list-conns 2>/dev/null)
        
        if [ -n "$CONNS" ]; then
            log_success "配置的连接："
            echo "$CONNS"
        else
            log_warning "没有配置的连接或配置有误"
        fi
    else
        log_warning "配置文件不存在，跳过测试"
    fi
    
    echo ""
}

# 主测试函数
main() {
    echo ""
    echo "========================================="
    echo "  strongSwan 5.9.6 安装配置测试"
    echo "========================================="
    echo ""
    
    check_root
    
    test_system_environment
    test_dependencies
    test_strongswan_installation
    test_configuration_files
    test_certificates
    test_network_configuration
    test_service_status
    test_logs
    test_crypto_algorithms
    test_connection_config
    
    echo "========================================="
    echo "  测试完成"
    echo "========================================="
    echo ""
    
    # 总结
    log_info "如果发现警告或错误，请参考 CentOS安装配置指南.md 进行修复"
    log_info "下一步："
    echo "  1. 修复配置问题"
    echo "  2. 启动 strongSwan: /usr/local/strongswan/sbin/ipsec start"
    echo "  3. 查看状态: /usr/local/strongswan/sbin/swanctl --list-sas"
    echo "  4. 查看日志: tail -f /var/log/strongswan.log"
    echo ""
}

# 运行主函数
main "$@"
