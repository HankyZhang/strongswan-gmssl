#!/bin/bash
# Generate server and client certificates signed by CA

set -e

PASSWORD="123456"
CA_KEY="/tmp/ca-key.pem"
CA_CERT="/tmp/ca-cert.pem"
VALIDITY_DAYS=365

echo "=== Generating Server Certificate ==="

# Server key and certificate
echo "Step 1: Generating server private key..."
gmssl sm2keygen -pass "${PASSWORD}" -out /tmp/server-key.pem

echo "Step 2: Generating server certificate request..."
gmssl reqgen \
    -C CN \
    -ST Beijing \
    -L Beijing \
    -O "VPN Server" \
    -CN vpn.example.com \
    -key /tmp/server-key.pem \
    -pass "${PASSWORD}" \
    -out /tmp/server-req.pem

echo "Step 3: Signing server certificate..."
gmssl reqsign \
    -in /tmp/server-req.pem \
    -days ${VALIDITY_DAYS} \
    -cacert "${CA_CERT}" \
    -key "${CA_KEY}" \
    -pass "${PASSWORD}" \
    -out /tmp/server-cert.pem

echo "Server certificate generated: /tmp/server-cert.pem"

echo ""
echo "=== Generating Client Certificate ==="

# Client key and certificate
echo "Step 1: Generating client private key..."
gmssl sm2keygen -pass "${PASSWORD}" -out /tmp/client-key.pem

echo "Step 2: Generating client certificate request..."
gmssl reqgen \
    -C CN \
    -ST Beijing \
    -L Beijing \
    -O "VPN Client" \
    -CN client@example.com \
    -key /tmp/client-key.pem \
    -pass "${PASSWORD}" \
    -out /tmp/client-req.pem

echo "Step 3: Signing client certificate..."
gmssl reqsign \
    -in /tmp/client-req.pem \
    -days ${VALIDITY_DAYS} \
    -cacert "${CA_CERT}" \
    -key "${CA_KEY}" \
    -pass "${PASSWORD}" \
    -out /tmp/client-cert.pem

echo "Client certificate generated: /tmp/client-cert.pem"

echo ""
echo "=== Verifying Certificates ==="
echo "Verifying server certificate..."
gmssl certverify -cacert "${CA_CERT}" -cert /tmp/server-cert.pem

echo ""
echo "Verifying client certificate..."
gmssl certverify -cacert "${CA_CERT}" -cert /tmp/client-cert.pem

echo ""
echo "=== Certificate Files Ready ==="
echo "Server Key:  /tmp/server-key.pem (password: ${PASSWORD})"
echo "Server Cert: /tmp/server-cert.pem"
echo "Client Key:  /tmp/client-key.pem (password: ${PASSWORD})"
echo "Client Cert: /tmp/client-cert.pem"
echo ""
echo "To install:"
echo "  cp /tmp/server-cert.pem /etc/swanctl/x509/servercert.pem"
echo "  cp /tmp/server-key.pem /etc/swanctl/private/serverkey.pem"
echo "  cp /tmp/client-cert.pem /etc/swanctl/x509/clientcert.pem"
echo "  cp /tmp/client-key.pem /etc/swanctl/private/clientkey.pem"
