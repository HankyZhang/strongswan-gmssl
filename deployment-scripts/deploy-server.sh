#!/bin/bash
# Deploy strongSwan Server (101.126.148.5)
# Run this script on the server machine

set -e

SERVER_IP="101.126.148.5"
CLIENT_IP="8.140.37.32"

echo "=========================================="
echo "Deploying strongSwan Server - SM2/SM3/SM4"
echo "Server IP: $SERVER_IP"
echo "Client IP: $CLIENT_IP"
echo "=========================================="

# Stop and remove existing container
echo "[1/6] Cleaning up existing containers..."
docker stop strongswan-server 2>/dev/null || true
docker rm strongswan-server 2>/dev/null || true

# Pull or load the image (assuming you've pushed it to a registry or saved as tar)
echo "[2/6] Loading strongSwan image..."
# If you have the image saved:
# docker load -i strongswan-gmssl.tar
# Or pull from registry:
# docker pull your-registry/strongswan-gmssl:latest

# Start the container
echo "[3/6] Starting strongSwan server container..."
docker run -d \
  --name strongswan-server \
  --privileged \
  --network host \
  --restart unless-stopped \
  strongswan-gmssl:latest

# Wait for charon to start
echo "[4/6] Waiting for charon to start..."
sleep 10

# Generate certificates
echo "[5/6] Generating SM2 certificates..."
docker exec strongswan-server bash -c "
cd /tmp
# Generate CA certificate
gmssl sm2keygen -pass 123456 -out ca-key.pem
gmssl certgen -C CN -O 'GMSM VPN CA' -CN 'GMSM Root CA' -days 3650 -key ca-key.pem -pass 123456 -out ca.pem

# Generate server certificate (101.126.148.5)
gmssl sm2keygen -pass 123456 -out server-key.pem
gmssl reqgen -C CN -O 'VPN Server' -CN 'vpn-server-101.126.148.5' -key server-key.pem -pass 123456 -out server.req
gmssl reqsign -in server.req -days 365 -cacert ca.pem -key ca-key.pem -pass 123456 -out server.crt

# Generate client certificate (8.140.37.32)
gmssl sm2keygen -pass 123456 -out client-key.pem
gmssl reqgen -C CN -O 'VPN Client' -CN 'vpn-client-8.140.37.32' -key client-key.pem -pass 123456 -out client.req
gmssl reqsign -in client.req -days 365 -cacert ca.pem -key ca-key.pem -pass 123456 -out client.crt

# Install server certificates
rm -f /etc/swanctl/x509/*.pem /etc/swanctl/x509ca/*.pem /etc/swanctl/private/*.pem 2>/dev/null
cp ca.pem /etc/swanctl/x509ca/cacert.pem
cp server.crt /etc/swanctl/x509/servercert.pem
cp server-key.pem /etc/swanctl/private/serverkey.pem

echo 'Server certificates installed'
"

# Load credentials and connections
echo "[6/6] Loading credentials and connections..."
docker exec strongswan-server bash -c "
swanctl --load-creds 2>&1 | grep -E 'loaded|SM2'
swanctl --load-conns 2>&1 | grep -E 'loaded|server-sm2'
"

echo ""
echo "=========================================="
echo "Server deployment complete!"
echo "=========================================="
echo "To export client certificates, run:"
echo "  docker exec strongswan-server cat /tmp/ca.pem > ca.pem"
echo "  docker exec strongswan-server cat /tmp/client.crt > client.crt"
echo "  docker exec strongswan-server cat /tmp/client-key.pem > client-key.pem"
echo ""
echo "Then transfer these files to the client machine at $CLIENT_IP"
echo ""
echo "To check status:"
echo "  docker exec strongswan-server swanctl --list-sas"
echo "  docker exec strongswan-server tail -f /var/log/charon.log"
