# strongSwan Docker 部署指南

> 在 Docker 容器中运行 strongSwan VPN 服务器

---

## 📋 前置要求

### Windows 系统

1. **安装 Docker Desktop**
   - 下载地址: https://www.docker.com/products/docker-desktop
   - 最低版本: Docker Desktop 4.0+
   - 启用 WSL2 后端（推荐）

2. **系统要求**
   - Windows 10 64-bit: Pro, Enterprise, or Education (Build 19041+)
   - Windows 11 64-bit: Home or Pro version 21H2+
   - 至少 4GB RAM
   - 启用虚拟化（在 BIOS 中）

### Linux 系统

```bash
# CentOS/RHEL
sudo yum install -y docker docker-compose

# Ubuntu/Debian
sudo apt install -y docker.io docker-compose

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker
```

---

## 🚀 快速启动

### 方法 1：使用 Docker Compose（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

# 2. 创建配置目录
mkdir -p config/swanctl/{x509,x509ca,private,rsa}
mkdir -p logs

# 3. 生成配置文件（可选，也可以手动创建）
# 如果在 Windows 上，需要在 WSL2 或 Git Bash 中运行
bash generate-config.sh

# 4. 构建并启动容器
docker-compose up -d

# 5. 查看日志
docker-compose logs -f

# 6. 查看状态
docker exec strongswan-vpn /usr/local/strongswan/sbin/swanctl --list-conns
```

### 方法 2：直接使用 Docker

```bash
# 1. 构建镜像
docker build -t strongswan-gmssl:5.9.6 .

# 2. 创建配置目录
mkdir -p $(pwd)/config/swanctl
mkdir -p $(pwd)/logs

# 3. 运行容器
docker run -d \
  --name strongswan-vpn \
  --privileged \
  --net=host \
  -v $(pwd)/config/swanctl:/etc/swanctl \
  -v $(pwd)/logs:/var/log \
  -e TZ=Asia/Shanghai \
  --restart unless-stopped \
  strongswan-gmssl:5.9.6

# 4. 查看日志
docker logs -f strongswan-vpn
```

---

## ⚙️ 配置说明

### 目录结构

```
strongswan-gmssl/
├── Dockerfile                  # Docker 镜像定义
├── docker-compose.yml          # Docker Compose 配置
├── config/                     # 配置文件目录
│   ├── swanctl/               # swanctl 配置
│   │   ├── swanctl.conf       # 连接配置
│   │   ├── x509/              # 证书
│   │   ├── x509ca/            # CA 证书
│   │   └── private/           # 私钥
│   └── strongswan.conf        # 全局配置
└── logs/                       # 日志目录
    └── strongswan.log
```

### 配置文件示例

#### 1. config/strongswan.conf

```conf
charon {
    filelog {
        /var/log/strongswan.log {
            time_format = %Y-%m-%d %H:%M:%S
            ike_name = yes
            append = no
            default = 1
            ike = 2
            cfg = 2
        }
    }
    
    plugins {
        openssl {
            load = yes
        }
    }
}
```

#### 2. config/swanctl/swanctl.conf

```conf
connections {
    vpn {
        remote_addrs = %any
        
        local {
            auth = pubkey
            certs = server-cert.pem
        }
        
        remote {
            auth = eap-mschapv2
            id = %any
        }
        
        children {
            tunnel {
                local_ts = 0.0.0.0/0
                esp_proposals = aes256gcm16-sha256
            }
        }
    }
}

pools {
    ippool {
        addrs = 10.10.10.0/24
        dns = 8.8.8.8
    }
}

secrets {
    eap-user {
        id = user@example.com
        secret = "password123"
    }
}
```

---

## 🔧 管理命令

### Docker Compose 命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f

# 查看状态
docker-compose ps

# 进入容器
docker-compose exec strongswan bash
```

### Docker 命令

```bash
# 查看运行中的容器
docker ps

# 查看日志
docker logs -f strongswan-vpn

# 进入容器
docker exec -it strongswan-vpn bash

# 重启容器
docker restart strongswan-vpn

# 停止容器
docker stop strongswan-vpn

# 删除容器
docker rm strongswan-vpn

# 查看容器资源使用
docker stats strongswan-vpn
```

### strongSwan 管理命令（容器内）

```bash
# 进入容器
docker exec -it strongswan-vpn bash

# 加载配置
swanctl --load-all

# 查看连接
swanctl --list-conns

# 查看 SA
swanctl --list-sas

# 查看证书
swanctl --list-certs

# 发起连接
swanctl --initiate --child tunnel

# 终止连接
swanctl --terminate --ike vpn
```

---

## 🔐 证书生成

### 在容器中生成证书

```bash
# 1. 进入容器
docker exec -it strongswan-vpn bash

# 2. 生成 CA 证书
pki --gen --type rsa --size 4096 --outform pem > /etc/swanctl/x509ca/ca-key.pem

pki --self --ca --lifetime 3650 \
    --in /etc/swanctl/x509ca/ca-key.pem \
    --type rsa --dn "C=CN, O=Example, CN=VPN CA" \
    --outform pem > /etc/swanctl/x509ca/ca-cert.pem

# 3. 生成服务器证书
pki --gen --type rsa --size 2048 --outform pem > /etc/swanctl/private/server-key.pem

pki --pub --in /etc/swanctl/private/server-key.pem --type rsa | \
pki --issue --lifetime 1825 \
    --cacert /etc/swanctl/x509ca/ca-cert.pem \
    --cakey /etc/swanctl/x509ca/ca-key.pem \
    --dn "C=CN, O=Example, CN=vpn.example.com" \
    --san vpn.example.com \
    --flag serverAuth --flag ikeIntermediate \
    --outform pem > /etc/swanctl/x509/server-cert.pem

# 4. 设置权限
chmod 600 /etc/swanctl/private/*
chmod 600 /etc/swanctl/x509ca/ca-key.pem

# 5. 加载证书
swanctl --load-creds

# 6. 退出容器
exit
```

---

## 🌐 网络配置

### Windows 上的网络模式

由于 Windows Docker Desktop 的限制，网络配置需要特别注意：

#### 选项 1：使用 host 网络（Linux 主机）

```yaml
# docker-compose.yml
services:
  strongswan:
    network_mode: host
```

**优点**：最简单，性能最好  
**缺点**：仅在 Linux 主机上工作，Windows 不支持

#### 选项 2：端口映射（Windows 推荐）

```yaml
# docker-compose.yml
services:
  strongswan:
    ports:
      - "500:500/udp"
      - "4500:4500/udp"
```

**需要额外配置**：
- 在 Windows 防火墙中开放端口
- 配置端口转发

#### 选项 3：使用 WSL2（Windows 推荐）

在 WSL2 中直接运行 Docker：

```bash
# 在 WSL2 Ubuntu 中
docker-compose up -d
```

---

## 🐛 故障排查

### 常见问题

#### 1. 容器无法启动

```bash
# 查看详细日志
docker logs strongswan-vpn

# 检查权限
docker run --rm --privileged strongswan-gmssl:5.9.6 /bin/bash -c "ls -la /etc/swanctl"
```

#### 2. VPN 连接失败

```bash
# 检查防火墙
# Windows
netsh advfirewall firewall show rule name=all | findstr 500
netsh advfirewall firewall show rule name=all | findstr 4500

# Linux
sudo firewall-cmd --list-ports
sudo iptables -L -n | grep 500
```

#### 3. 证书问题

```bash
# 验证证书
docker exec strongswan-vpn openssl x509 -in /etc/swanctl/x509/server-cert.pem -noout -text

# 重新加载证书
docker exec strongswan-vpn swanctl --load-creds
```

#### 4. 性能问题

```bash
# 查看资源使用
docker stats strongswan-vpn

# 限制资源使用
docker update --cpus 2 --memory 2g strongswan-vpn
```

---

## 🔄 更新和维护

### 更新镜像

```bash
# 1. 拉取最新代码
git pull

# 2. 重新构建镜像
docker-compose build --no-cache

# 3. 重启服务
docker-compose down
docker-compose up -d
```

### 备份配置

```bash
# 备份配置和证书
tar -czf strongswan-backup-$(date +%Y%m%d).tar.gz config/

# 备份日志
tar -czf strongswan-logs-$(date +%Y%m%d).tar.gz logs/
```

### 恢复配置

```bash
# 解压备份
tar -xzf strongswan-backup-20251030.tar.gz

# 重启容器
docker-compose restart
```

---

## ⚠️ Windows 特别注意事项

### 1. WSL2 集成

Docker Desktop 使用 WSL2 后端时：
- ✅ 性能更好
- ✅ 文件系统更快
- ✅ 网络更稳定

启用方法：
```
Docker Desktop → Settings → General → Use WSL 2 based engine
```

### 2. 文件权限

Windows 文件系统不支持 Linux 权限，需要在容器内设置：

```bash
docker exec strongswan-vpn chmod 600 /etc/swanctl/private/*
```

### 3. 路径问题

在 Windows PowerShell 中使用绝对路径：

```powershell
# 正确
docker run -v C:\Code\strongswan-gmssl\config:/etc/swanctl ...

# 错误（相对路径）
docker run -v .\config:/etc/swanctl ...
```

---

## 📊 生产环境部署

### 推荐配置

```yaml
version: '3.8'

services:
  strongswan:
    image: strongswan-gmssl:5.9.6
    container_name: strongswan-prod
    privileged: true
    network_mode: host
    
    volumes:
      - /etc/swanctl:/etc/swanctl:ro
      - /var/log/strongswan:/var/log
    
    environment:
      - TZ=Asia/Shanghai
    
    restart: always
    
    resources:
      limits:
        cpus: '2'
        memory: 2G
      reservations:
        cpus: '1'
        memory: 1G
    
    healthcheck:
      test: ["CMD", "swanctl", "--stats"]
      interval: 60s
      timeout: 10s
      retries: 5
      start_period: 30s
    
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "10"
```

---

## 📚 参考资料

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [strongSwan 官方文档](https://docs.strongswan.org/)
- [WSL2 安装指南](https://docs.microsoft.com/en-us/windows/wsl/install)

---

**最后更新**: 2025-10-30  
**适用版本**: strongSwan 5.9.6, Docker 24+
