#!/bin/bash
#==============================================================================
# SM2 证书链生成脚本
# 用途: 为 strongSwan VPN 生成完整的 SM2 证书体系
# 依赖: GmSSL 3.1+
#==============================================================================

set -e

# 配置参数
CA_PASS="ca1234"
SERVER_PASS="server1234"
CLIENT_PASS="client1234"
CA_DAYS=3650
CERT_DAYS=365

# 证书信息
CA_CN="SM2 Root CA"
SERVER_CN="vpn.example.com"
CLIENT_CN="client@example.com"

COUNTRY="CN"
STATE="Beijing"
CITY="Beijing"
ORG_CA="Test CA Organization"
ORG_SERVER="VPN Server Organization"
ORG_CLIENT="VPN Client Organization"

# 输出目录
CERT_DIR="/etc/swanctl"
CA_DIR="${CERT_DIR}/x509ca"
X509_DIR="${CERT_DIR}/x509"
PRIVATE_DIR="${CERT_DIR}/private"

echo "============================================================"
echo "  SM2 证书链生成脚本"
echo "  strongSwan + GmSSL"
echo "============================================================"
echo ""

# 检查 GmSSL
if ! command -v gmssl &> /dev/null; then
    echo "错误: 未找到 gmssl 命令"
    echo "请先安装 GmSSL: https://github.com/guanzhi/GmSSL"
    exit 1
fi

echo "GmSSL 版本:"
gmssl version
echo ""

# 创建目录
echo "[1/6] 创建证书目录..."
sudo mkdir -p "${CA_DIR}" "${X509_DIR}" "${PRIVATE_DIR}"
sudo chmod 755 "${CA_DIR}" "${X509_DIR}"
sudo chmod 700 "${PRIVATE_DIR}"
echo "✓ 目录创建完成"
echo ""

# 生成 CA
echo "[2/6] 生成 CA 密钥和证书..."
cd /tmp

# CA 私钥
gmssl sm2keygen -pass "${CA_PASS}" -out ca_key.pem
echo "✓ CA 私钥生成完成"

# CA 证书
gmssl certgen \
    -C "${COUNTRY}" \
    -ST "${STATE}" \
    -L "${CITY}" \
    -O "${ORG_CA}" \
    -CN "${CA_CN}" \
    -days "${CA_DAYS}" \
    -key ca_key.pem \
    -pass "${CA_PASS}" \
    -out ca_cert.pem

echo "✓ CA 证书生成完成"
echo ""

# 生成服务器证书
echo "[3/6] 生成服务器密钥和证书..."

# 服务器私钥
gmssl sm2keygen -pass "${SERVER_PASS}" -out server_key.pem
echo "✓ 服务器私钥生成完成"

# 服务器证书请求
gmssl reqgen \
    -C "${COUNTRY}" \
    -ST "${STATE}" \
    -L "${CITY}" \
    -O "${ORG_SERVER}" \
    -CN "${SERVER_CN}" \
    -key server_key.pem \
    -pass "${SERVER_PASS}" \
    -out server.req

echo "✓ 服务器证书请求生成完成"

# 签发服务器证书
gmssl reqsign \
    -in server.req \
    -days "${CERT_DAYS}" \
    -key_usage digitalSignature \
    -key_usage keyEncipherment \
    -cacert ca_cert.pem \
    -key ca_key.pem \
    -pass "${CA_PASS}" \
    -out server_cert.pem

echo "✓ 服务器证书签发完成"
echo ""

# 生成客户端证书
echo "[4/6] 生成客户端密钥和证书..."

# 客户端私钥
gmssl sm2keygen -pass "${CLIENT_PASS}" -out client_key.pem
echo "✓ 客户端私钥生成完成"

# 客户端证书请求
gmssl reqgen \
    -C "${COUNTRY}" \
    -ST "${STATE}" \
    -L "${CITY}" \
    -O "${ORG_CLIENT}" \
    -CN "${CLIENT_CN}" \
    -key client_key.pem \
    -pass "${CLIENT_PASS}" \
    -out client.req

echo "✓ 客户端证书请求生成完成"

# 签发客户端证书
gmssl reqsign \
    -in client.req \
    -days "${CERT_DAYS}" \
    -key_usage digitalSignature \
    -cacert ca_cert.pem \
    -key ca_key.pem \
    -pass "${CA_PASS}" \
    -out client_cert.pem

echo "✓ 客户端证书签发完成"
echo ""

# 安装证书
echo "[5/6] 安装证书到 strongSwan 目录..."

# CA 证书
sudo cp ca_cert.pem "${CA_DIR}/cacert.pem"
sudo chmod 644 "${CA_DIR}/cacert.pem"
echo "✓ CA 证书: ${CA_DIR}/cacert.pem"

# 服务器证书和私钥
sudo cp server_cert.pem "${X509_DIR}/servercert.pem"
sudo cp server_key.pem "${PRIVATE_DIR}/serverkey.pem"
sudo chmod 644 "${X509_DIR}/servercert.pem"
sudo chmod 600 "${PRIVATE_DIR}/serverkey.pem"
echo "✓ 服务器证书: ${X509_DIR}/servercert.pem"
echo "✓ 服务器私钥: ${PRIVATE_DIR}/serverkey.pem"

# 客户端证书和私钥
sudo cp client_cert.pem "${X509_DIR}/clientcert.pem"
sudo cp client_key.pem "${PRIVATE_DIR}/clientkey.pem"
sudo chmod 644 "${X509_DIR}/clientcert.pem"
sudo chmod 600 "${PRIVATE_DIR}/clientkey.pem"
echo "✓ 客户端证书: ${X509_DIR}/clientcert.pem"
echo "✓ 客户端私钥: ${PRIVATE_DIR}/clientkey.pem"

echo ""

# 验证证书
echo "[6/6] 验证证书..."

echo "服务器证书信息:"
gmssl certparse -in server_cert.pem | grep -E "(Subject|Issuer|Not Before|Not After)" || true
echo ""

echo "客户端证书信息:"
gmssl certparse -in client_cert.pem | grep -E "(Subject|Issuer|Not Before|Not After)" || true
echo ""

# 验证证书链
echo "验证服务器证书链..."
gmssl certverify -in server_cert.pem -CAfile ca_cert.pem && echo "✓ 服务器证书验证通过" || echo "✗ 服务器证书验证失败"

echo "验证客户端证书链..."
gmssl certverify -in client_cert.pem -CAfile ca_cert.pem && echo "✓ 客户端证书验证通过" || echo "✗ 客户端证书验证失败"

echo ""
echo "============================================================"
echo "  证书生成完成！"
echo "============================================================"
echo ""
echo "证书文件位置:"
echo "  CA 证书:      ${CA_DIR}/cacert.pem"
echo "  服务器证书:   ${X509_DIR}/servercert.pem"
echo "  服务器私钥:   ${PRIVATE_DIR}/serverkey.pem"
echo "  客户端证书:   ${X509_DIR}/clientcert.pem"
echo "  客户端私钥:   ${PRIVATE_DIR}/clientkey.pem"
echo ""
echo "证书密码:"
echo "  CA 私钥:      ${CA_PASS}"
echo "  服务器私钥:   ${SERVER_PASS}"
echo "  客户端私钥:   ${CLIENT_PASS}"
echo ""
echo "下一步:"
echo "  1. 编辑 /etc/swanctl/swanctl.conf 配置 VPN 连接"
echo "  2. 运行 'sudo swanctl --load-all' 加载配置"
echo "  3. 运行 'sudo swanctl --list-certs' 查看证书"
echo "  4. 运行 'sudo swanctl --initiate --child <connection>' 发起连接"
echo ""

# 保存密码到文件（可选）
cat > /tmp/cert_passwords.txt << EOF
SM2 证书密码信息
=================
生成时间: $(date)

CA 私钥密码:     ${CA_PASS}
服务器私钥密码:  ${SERVER_PASS}
客户端私钥密码:  ${CLIENT_PASS}

证书有效期:
- CA:       ${CA_DAYS} 天
- 服务器:   ${CERT_DAYS} 天
- 客户端:   ${CERT_DAYS} 天
EOF

echo "密码信息已保存到: /tmp/cert_passwords.txt"
echo "⚠️  请妥善保管此文件，包含私钥密码！"
echo ""
