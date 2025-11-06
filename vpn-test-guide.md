# strongSwan 国密算法 VPN 测试指南

## 📋 测试环境

- **本地端**: Docker 容器 (strongswan-gmssl:3.1.1) - Windows 主机
- **远程端**: SSH 服务器 (101.126.148.5) - Linux 主机
- **加密算法**: SM2 (密钥交换) + SM3 (认证) + SM4 (加密)

---

## 🔧 方案一：Docker 作为 VPN 服务端

### 步骤 1: 在 Docker 中配置 VPN 服务端

#### 1.1 生成 SM2 证书（服务端）

```bash
# 在 Docker 容器中执行
docker run -it --rm \
  -v ${PWD}/vpn-certs:/certs \
  strongswan-gmssl:3.1.1 bash

# 生成 CA 证书
cd /certs
gmssl sm2keygen -pass 1234 -out ca-key.pem
gmssl certgen -C CN -ST Beijing -L Beijing -O "VPN Test CA" \
  -CN "VPN CA" -days 3650 -key ca-key.pem -pass 1234 -out ca-cert.pem

# 生成服务端证书
gmssl sm2keygen -pass 1234 -out server-key.pem
gmssl reqgen -C CN -ST Beijing -L Beijing -O "VPN Server" \
  -CN "vpn.server.local" -key server-key.pem -pass 1234 -out server-req.pem
gmssl reqsign -in server-req.pem -days 365 \
  -key ca-key.pem -pass 1234 -cacert ca-cert.pem -out server-cert.pem

# 生成客户端证书
gmssl sm2keygen -pass 1234 -out client-key.pem
gmssl reqgen -C CN -ST Beijing -L Beijing -O "VPN Client" \
  -CN "vpn.client.local" -key client-key.pem -pass 1234 -out client-req.pem
gmssl reqsign -in client-req.pem -days 365 \
  -key ca-key.pem -pass 1234 -cacert ca-cert.pem -out client-cert.pem
```

#### 1.2 配置 strongSwan 服务端

创建 `/etc/swanctl/swanctl.conf`:

```conf
connections {
    gmsm-vpn {
        version = 2
        proposals = sm2-sm3-sm4cbc
        local_addrs = 0.0.0.0
        remote_addrs = %any
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = vpn.server.local
        }
        
        remote {
            auth = pubkey
            id = vpn.client.local
        }
        
        children {
            gmsm-tunnel {
                local_ts = 10.0.0.0/24
                remote_ts = 0.0.0.0/0
                esp_proposals = sm4cbc-sm3
                mode = tunnel
            }
        }
    }
}

secrets {
    private-server {
        file = server-key.pem
    }
}
```

---

## 🔧 方案二：Docker 作为 VPN 客户端（推荐）

这个方案更简单，远程服务器作为 VPN 服务端。

### 步骤 1: 在远程服务器上安装 strongSwan

```bash
# SSH 连接到远程服务器
ssh root@101.126.148.5

# 安装标准 strongSwan (作为对照组)
apt-get update
apt-get install -y strongswan strongswan-pki

# 或者安装支持国密的版本
# 需要将 Docker 镜像导出并传输到远程服务器
```

### 步骤 2: 生成证书（使用标准算法对比）

```bash
# 在远程服务器上
cd /etc/ipsec.d

# 生成 CA
ipsec pki --gen --type rsa --size 4096 --outform pem > private/ca-key.pem
ipsec pki --self --ca --lifetime 3650 \
  --in private/ca-key.pem --type rsa \
  --dn "CN=VPN CA" --outform pem > cacerts/ca-cert.pem

# 生成服务端证书
ipsec pki --gen --type rsa --size 2048 --outform pem > private/server-key.pem
ipsec pki --pub --in private/server-key.pem --type rsa | \
  ipsec pki --issue --lifetime 1825 --cacert cacerts/ca-cert.pem \
  --cakey private/ca-key.pem --dn "CN=101.126.148.5" \
  --san 101.126.148.5 --flag serverAuth --flag ikeIntermediate \
  --outform pem > certs/server-cert.pem

# 生成客户端证书
ipsec pki --gen --type rsa --size 2048 --outform pem > private/client-key.pem
ipsec pki --pub --in private/client-key.pem --type rsa | \
  ipsec pki --issue --lifetime 1825 --cacert cacerts/ca-cert.pem \
  --cakey private/ca-key.pem --dn "CN=vpn-client" \
  --outform pem > certs/client-cert.pem
```

### 步骤 3: 配置远程服务器（标准算法）

编辑 `/etc/ipsec.conf`:

```conf
config setup
    charondebug="ike 2, knl 2, cfg 2"
    uniqueids=no

conn vpn-server
    type=tunnel
    auto=add
    keyexchange=ikev2
    authby=pubkey
    left=%any
    leftid=@101.126.148.5
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=pubkey
    rightsourceip=10.10.10.0/24
    ike=aes256-sha2_256-modp2048!
    esp=aes256-sha2_256!
```

编辑 `/etc/ipsec.secrets`:

```
: RSA server-key.pem
```

启动服务：

```bash
systemctl restart strongswan-starter
ipsec status
```

### 步骤 4: Docker 客户端连接

```bash
# 从远程服务器复制 CA 证书和客户端证书到本地
scp root@101.126.148.5:/etc/ipsec.d/cacerts/ca-cert.pem ./vpn-certs/
scp root@101.126.148.5:/etc/ipsec.d/certs/client-cert.pem ./vpn-certs/
scp root@101.126.148.5:/etc/ipsec.d/private/client-key.pem ./vpn-certs/

# 启动 Docker 客户端
docker run -it --rm --privileged \
  --network host \
  -v ${PWD}/vpn-certs:/certs \
  strongswan-gmssl:3.1.1 bash
```

在容器内配置客户端 `/etc/swanctl/swanctl.conf`:

```conf
connections {
    vpn-client {
        version = 2
        remote_addrs = 101.126.148.5
        
        local {
            auth = pubkey
            certs = client-cert.pem
            id = vpn-client
        }
        
        remote {
            auth = pubkey
            id = @101.126.148.5
        }
        
        children {
            tunnel {
                remote_ts = 0.0.0.0/0
                esp_proposals = aes256-sha256
            }
        }
    }
}

secrets {
    private-client {
        file = /certs/client-key.pem
    }
}
```

启动连接：

```bash
swanctl --load-all
swanctl --initiate --child tunnel
swanctl --list-sas
```

---

## 🧪 方案三：完整国密算法测试（需要远程服务器支持）

### 前提条件

远程服务器需要安装支持国密的 strongSwan 版本。

### 选项 A: 将 Docker 镜像传输到远程服务器

```powershell
# 在本地导出 Docker 镜像
docker save strongswan-gmssl:3.1.1 | gzip > strongswan-gmssl-3.1.1.tar.gz

# 传输到远程服务器
scp strongswan-gmssl-3.1.1.tar.gz root@101.126.148.5:/tmp/

# 在远程服务器导入
ssh root@101.126.148.5
docker load < /tmp/strongswan-gmssl-3.1.1.tar.gz
```

### 选项 B: 直接在远程服务器编译

```bash
# SSH 到远程服务器
ssh root@101.126.148.5

# 克隆仓库
git clone https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

# 使用 Docker 编译（如果远程有 Docker）
./build-gmssl.sh

# 或者直接编译安装
apt-get install -y build-essential libgmp-dev
cd /tmp
git clone https://github.com/guanzhi/GmSSL.git
cd GmSSL
mkdir build && cd build
cmake ..
make && make install

cd /root/strongswan-gmssl
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc \
  --enable-gmsm --with-gmssl=/usr/local
make && make install
```

### 国密 VPN 配置

**服务端** (101.126.148.5):

```conf
connections {
    gmsm-server {
        version = 2
        proposals = sm2-sm3-sm4cbc
        local_addrs = 0.0.0.0
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = vpn.server.local
        }
        
        remote {
            auth = pubkey
        }
        
        children {
            gmsm-net {
                local_ts = 0.0.0.0/0
                esp_proposals = sm4cbc-sm3
                mode = tunnel
            }
        }
    }
}
```

**客户端** (Docker):

```conf
connections {
    gmsm-client {
        version = 2
        proposals = sm2-sm3-sm4cbc
        remote_addrs = 101.126.148.5
        
        local {
            auth = pubkey
            certs = client-cert.pem
            id = vpn.client.local
        }
        
        remote {
            auth = pubkey
            id = vpn.server.local
        }
        
        children {
            gmsm-net {
                remote_ts = 0.0.0.0/0
                esp_proposals = sm4cbc-sm3
            }
        }
    }
}
```

---

## 🧪 测试验证

### 1. 检查连接状态

```bash
# 查看 IKE SA
swanctl --list-sas

# 查看 ESP SA
ip xfrm state
ip xfrm policy
```

### 2. 验证加密算法

```bash
# 查看使用的加密套件
swanctl --list-sas | grep -i "encr\|integ\|prf"
```

### 3. 测试网络连通性

```bash
# 在客户端 ping 服务端内网
ping 10.10.10.1

# 测试流量是否加密
tcpdump -i any esp
```

### 4. 性能测试

```bash
# 安装 iperf3
apt-get install -y iperf3

# 服务端
iperf3 -s

# 客户端
iperf3 -c 10.10.10.1 -t 30
```

---

## 📊 预期结果

### 成功指标

- ✅ IKE SA 建立成功
- ✅ ESP SA 建立成功
- ✅ 使用 SM2/SM3/SM4 算法
- ✅ 网络流量正常转发
- ✅ 加密流量可见 (ESP 包)

### 日志查看

```bash
# strongSwan 日志
journalctl -u strongswan -f

# 或容器内
tail -f /var/log/syslog
```

---

## ⚠️ 常见问题

### 1. 证书问题

```bash
# 验证证书
gmssl certparse -in server-cert.pem

# 检查私钥
gmssl sm2keyparse -in server-key.pem -pass 1234
```

### 2. 网络问题

```bash
# 检查防火墙
iptables -L -n
ufw status

# 开放 IKE 端口
ufw allow 500/udp
ufw allow 4500/udp
ufw allow 50/esp
```

### 3. 算法协商失败

```bash
# 查看支持的算法
swanctl --list-algs
ipsec listcerts
```

---

## 🎯 推荐测试路径

1. **第一阶段**: 使用方案二，标准算法验证连通性
2. **第二阶段**: 在远程服务器安装国密 strongSwan
3. **第三阶段**: 使用方案三，完整国密算法测试

---

## 📝 测试记录模板

```
测试日期: ____________________
测试方案: [ ] 方案一  [ ] 方案二  [ ] 方案三
加密算法: [ ] 标准  [ ] 国密

服务端信息:
- IP: ____________________
- 系统: ____________________
- strongSwan 版本: ____________________

客户端信息:
- IP: ____________________
- 系统: ____________________
- strongSwan 版本: ____________________

测试结果:
- IKE 协商: [ ] 成功  [ ] 失败
- ESP 建立: [ ] 成功  [ ] 失败
- 网络连通: [ ] 成功  [ ] 失败
- 算法验证: [ ] 成功  [ ] 失败

性能数据:
- 吞吐量: __________ Mbps
- 延迟: __________ ms
- 丢包率: __________ %

备注:
_________________________________
_________________________________
```
