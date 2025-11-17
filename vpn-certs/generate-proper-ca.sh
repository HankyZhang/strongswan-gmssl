#!/bin/bash
# Generate proper CA certificate with X.509v3 extensions for strongSwan

set -e

PASSWORD="123456"
VALIDITY_DAYS=3650

echo "=== Generating CA Certificate with Extensions ==="

# Create temporary OpenSSL config for CA extensions
cat > /tmp/ca_ext.cnf << 'EOF'
[ req ]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[ req_distinguished_name ]
C = CN
ST = Beijing
L = Beijing
O = VPN CA
CN = VPN Root CA

[ v3_ca ]
basicConstraints = critical,CA:TRUE,pathlen:1
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

# Step 1: Generate CA private key with GmSSL
echo "Step 1: Generating CA private key..."
gmssl sm2keygen -pass "${PASSWORD}" -out /tmp/ca-key.pem
echo "CA private key generated: /tmp/ca-key.pem"

# Step 2: Generate CA certificate with extensions
# Note: GmSSL may not support all x509v3 extensions, try both approaches

echo "Step 2: Attempting to generate CA certificate with extensions..."

# Approach 1: Use openssl if available (for extensions)
if command -v openssl &> /dev/null; then
    echo "Using OpenSSL for certificate generation (better extension support)..."
    openssl req -new -x509 -days ${VALIDITY_DAYS} \
        -sm3 \
        -key /tmp/ca-key.pem \
        -out /tmp/ca-cert.pem \
        -config /tmp/ca_ext.cnf \
        -passin pass:${PASSWORD} 2>&1 || {
        echo "OpenSSL approach failed, falling back to GmSSL..."
        
        # Approach 2: Pure GmSSL (may lack some extensions)
        echo "Using GmSSL for certificate generation..."
        gmssl certgen \
            -C CN \
            -ST Beijing \
            -L Beijing \
            -O "VPN CA" \
            -CN "VPN Root CA" \
            -days ${VALIDITY_DAYS} \
            -key /tmp/ca-key.pem \
            -pass ${PASSWORD} \
            -out /tmp/ca-cert.pem \
            -subca \
            -pathlen 1
    }
else
    # Pure GmSSL approach
    echo "Using GmSSL for certificate generation (OpenSSL not available)..."
    gmssl certgen \
        -C CN \
        -ST Beijing \
        -L Beijing \
        -O "VPN CA" \
        -CN "VPN Root CA" \
        -days ${VALIDITY_DAYS} \
        -key /tmp/ca-key.pem \
        -pass ${PASSWORD} \
        -out /tmp/ca-cert.pem \
        -subca \
        -pathlen 1
fi

echo "CA certificate generated: /tmp/ca-cert.pem"

# Step 3: Verify certificate
echo ""
echo "=== CA Certificate Details ==="
gmssl certparse -in /tmp/ca-cert.pem

echo ""
echo "=== Checking for Extensions ==="
gmssl certparse -in /tmp/ca-cert.pem | grep -i "extension" -A 5 || echo "No extensions found (may need manual addition)"

echo ""
echo "=== Certificate Files Ready ==="
echo "CA Key:  /tmp/ca-key.pem (password: ${PASSWORD})"
echo "CA Cert: /tmp/ca-cert.pem"
echo ""
echo "To install:"
echo "  cp /tmp/ca-cert.pem /etc/swanctl/x509ca/cacert.pem"
echo "  cp /tmp/ca-key.pem /etc/swanctl/private/cakey.pem"
