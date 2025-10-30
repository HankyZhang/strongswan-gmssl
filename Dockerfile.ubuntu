# Dockerfile for strongSwan 5.9.6 (Ubuntu 22.04)
FROM ubuntu:22.04

LABEL maintainer="HankyZhang" \
      description="strongSwan 5.9.6 IPsec VPN (Ubuntu)" \
      version="5.9.6"

ENV DEBIAN_FRONTEND=noninteractive \
    STRONGSWAN_VERSION=5.9.6 \
    STRONGSWAN_PREFIX=/usr/local/strongswan

RUN apt-get update && apt-get install -y \
    build-essential libpam0g-dev libssl-dev pkg-config \
    libgmp3-dev gettext wget libsystemd-dev \
    libcurl4-openssl-dev libcap-ng-dev \
    iptables iproute2 net-tools vim \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp \
    && wget https://download.strongswan.org/strongswan-5.9.6.tar.gz \
    && tar -zxf strongswan-5.9.6.tar.gz \
    && cd strongswan-5.9.6 \
    && ./configure --prefix=/usr/local/strongswan --sysconfdir=/etc \
        --enable-eap-identity --enable-eap-md5 --enable-eap-mschapv2 \
        --enable-eap-tls --enable-dhcp --enable-openssl \
        --enable-tools --enable-swanctl --enable-vici --disable-gmp \
    && make -j $(nproc) \
    && make install \
    && rm -rf /tmp/strongswan-*

ENV PATH="/usr/local/strongswan/bin:/usr/local/strongswan/sbin:${PATH}"

RUN mkdir -p /etc/swanctl/x509 /etc/swanctl/x509ca /etc/swanctl/private /etc/swanctl/rsa /etc/swanctl/conf.d \
    && chmod 700 /etc/swanctl/private

RUN printf '#!/bin/bash\n\
set -e\n\
echo "=== strongSwan Starting ==="\n\
sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true\n\
if [ -f /etc/swanctl/swanctl.conf ]; then\n\
  echo "Configuration file found"\n\
else\n\
  echo "Warning: No configuration file found"\n\
fi\n\
echo "Starting charon daemon..."\n\
exec /usr/local/strongswan/libexec/ipsec/charon\n' > /start.sh \
    && chmod +x /start.sh

EXPOSE 500/udp 4500/udp

CMD ["/start.sh"]
