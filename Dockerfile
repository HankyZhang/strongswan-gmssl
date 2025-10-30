# Dockerfile for strongSwan 5.9.6 with GmSSL support
# 
# 构建镜像:
#   docker build -t strongswan-gmssl:5.9.6 .
#
# 运行容器:
#   docker run -d --name strongswan --privileged --net=host \
#     -v /etc/swanctl:/etc/swanctl \
#     strongswan-gmssl:5.9.6

FROM centos:7

LABEL maintainer="HankyZhang" \
      description="strongSwan 5.9.6 IPsec VPN with GmSSL support" \
      version="5.9.6"

# 设置环境变量
ENV STRONGSWAN_VERSION=5.9.6 \
    STRONGSWAN_PREFIX=/usr/local/strongswan

# 安装依赖
RUN yum install -y \
    pam-devel \
    openssl-devel \
    make \
    gcc \
    gmp-devel \
    gettext-devel \
    wget \
    systemd-devel \
    curl-devel \
    libcap-ng-devel \
    && yum clean all

# 下载并编译 strongSwan
RUN cd /tmp \
    && wget https://download.strongswan.org/strongswan-${STRONGSWAN_VERSION}.tar.gz \
    && tar -zxvf strongswan-${STRONGSWAN_VERSION}.tar.gz \
    && cd strongswan-${STRONGSWAN_VERSION} \
    && ./configure \
        --prefix=${STRONGSWAN_PREFIX} \
        --sysconfdir=/etc \
        --enable-eap-identity \
        --enable-eap-md5 \
        --enable-eap-mschapv2 \
        --enable-eap-tls \
        --enable-eap-ttls \
        --enable-eap-peap \
        --enable-eap-tnc \
        --enable-eap-dynamic \
        --enable-eap-radius \
        --enable-xauth-eap \
        --enable-xauth-pam \
        --enable-dhcp \
        --enable-openssl \
        --enable-addrblock \
        --enable-unity \
        --enable-certexpire \
        --enable-radattr \
        --enable-tools \
        --enable-swanctl \
        --enable-vici \
        --disable-gmp \
    && make -j $(nproc) \
    && make install \
    && cd / \
    && rm -rf /tmp/strongswan-${STRONGSWAN_VERSION}*

# 创建配置目录
RUN mkdir -p /etc/swanctl/{x509,x509ca,private,rsa} \
    && chmod 700 /etc/swanctl/private

# 创建日志目录
RUN mkdir -p /var/log

# 复制配置文件（如果有）
# COPY swanctl.conf /etc/swanctl/swanctl.conf
# COPY strongswan.conf /etc/strongswan.conf

# 创建启动脚本
RUN echo '#!/bin/bash' > /start.sh \
    && echo 'set -e' >> /start.sh \
    && echo '' >> /start.sh \
    && echo '# 配置内核参数' >> /start.sh \
    && echo 'sysctl -w net.ipv4.ip_forward=1' >> /start.sh \
    && echo 'sysctl -w net.ipv4.conf.all.accept_redirects=0' >> /start.sh \
    && echo 'sysctl -w net.ipv4.conf.all.send_redirects=0' >> /start.sh \
    && echo '' >> /start.sh \
    && echo '# 加载配置' >> /start.sh \
    && echo 'if [ -f /etc/swanctl/swanctl.conf ]; then' >> /start.sh \
    && echo '    /usr/local/strongswan/sbin/swanctl --load-all' >> /start.sh \
    && echo 'fi' >> /start.sh \
    && echo '' >> /start.sh \
    && echo '# 启动 strongSwan' >> /start.sh \
    && echo 'exec /usr/local/strongswan/sbin/charon' >> /start.sh \
    && chmod +x /start.sh

# 暴露端口
EXPOSE 500/udp 4500/udp

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD /usr/local/strongswan/sbin/swanctl --stats || exit 1

# 启动命令
CMD ["/start.sh"]
