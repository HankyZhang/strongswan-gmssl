#!/bin/bash
# Deploy strongSwan Client (8.140.37.32)
# Run this script on the client machine after transferring certificates from server

set -e

SERVER_IP="101.126.148.5"
CLIENT_IP="8.140.37.32"

echo "=========================================="
echo "Deploying strongSwan Client - SM2/SM3/SM4"
echo "Client IP: $CLIENT_IP"
echo "Server IP: $SERVER_IP"
echo "=========================================="

# Check if certificates exist
if [ ! -f "ca.pem" ] || [ ! -f "client.crt" ] || [ ! -f "client-key.pem" ]; then
    echo "ERROR: Certificates not found!"
    echo "Please copy the following files from the server:"
    echo "  - ca.pem"
    echo "  - client.crt"
    echo "  - client-key.pem"
    exit 1
fi

# Stop and remove existing container
echo "[1/5] Cleaning up existing containers..."
docker stop strongswan-client 2>/dev/null || true
docker rm strongswan-client 2>/dev/null || true

# Start the container
echo "[2/5] Starting strongSwan client container..."
docker run -d \
  --name strongswan-client \
  --privileged \
  --network host \
  --restart unless-stopped \
  strongswan-gmssl:latest

# Wait for charon to start
echo "[3/5] Waiting for charon to start..."
sleep 10

# Install client certificates
echo "[4/5] Installing client certificates..."
docker exec strongswan-client bash -c "
rm -f /etc/swanctl/x509/*.pem /etc/swanctl/x509ca/*.pem /etc/swanctl/private/*.pem 2>/dev/null
mkdir -p /etc/swanctl/x509ca /etc/swanctl/x509 /etc/swanctl/private
chmod 700 /etc/swanctl/private
"

docker cp ca.pem strongswan-client:/etc/swanctl/x509ca/cacert.pem
docker cp client.crt strongswan-client:/etc/swanctl/x509/clientcert.pem
docker cp client-key.pem strongswan-client:/etc/swanctl/private/clientkey.pem

docker exec strongswan-client chmod 600 /etc/swanctl/private/clientkey.pem

# Load credentials and connections
echo "[5/5] Loading credentials and connections..."
docker exec strongswan-client bash -c "
swanctl --load-creds 2>&1 | grep -E 'loaded|SM2'
swanctl --load-conns 2>&1 | grep -E 'loaded|client-sm2'
"

echo ""
echo "=========================================="
echo "Client deployment complete!"
echo "=========================================="
echo "To initiate VPN connection:"
echo "  docker exec strongswan-client swanctl --initiate --child client-tunnel"
echo ""
echo "To check status:"
echo "  docker exec strongswan-client swanctl --list-sas"
echo "  docker exec strongswan-client tail -f /var/log/charon.log"
echo ""
echo "To test the tunnel after connection is established:"
echo "  docker exec strongswan-client ping -c 4 10.10.0.1"
