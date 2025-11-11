# 国密算法 VPN 测试指南

## 问题诊断总结

### 核心问题
**100% 确认：Windows Docker Desktop 的网络限制导致 VPN 连接失败**

### 证据链
✅ **阿里云安全组配置正确**（UDP 500/4500 已开放）  
✅ **服务器 iptables 规则正确**（已显示接收数据包）  
✅ **服务器容器正在监听** UDP 500/4500  
✅ **GMSM 插件工作正常**（已加载并可用）  
❌ **客户端使用 192.168.65.3（Docker 内部 IP）无法路由**

### 根本原因
Windows Docker Desktop 的 `--network host` 模式在 Windows 上**不起作用**！

- Docker Desktop 使用 WSL2 虚拟机运行容器
- 容器获得的是 WSL2 虚拟机的内部 IP（如 192.168.65.3）
- 该 IP 无法被远程服务器路由回来
- IKE 协议需要双向 UDP 通信，但响应包无法到达客户端

---

## 解决方案

### 方案 1：在 Linux 服务器上测试（推荐）

**优点**：
- `network_mode: host` 真正有效
- 真实的生产环境测试
- 完整的 GMSM 算法支持测试

**步骤**：

#### 1.1 准备第二台服务器作为客户端
```bash
# 假设使用另一台 Linux 机器作为客户端
CLIENT_IP=your.client.ip

# 从 Windows 上传客户端配置
scp config/swanctl/gmsm-psk-client.conf root@$CLIENT_IP:/tmp/
```

#### 1.2 在客户端服务器上部署
```bash
ssh root@$CLIENT_IP

# 创建配置目录
mkdir -p /etc/strongswan-docker/swanctl

# 复制客户端配置
cp /tmp/gmsm-psk-client.conf /etc/strongswan-docker/swanctl/swanctl.conf

# 拉取 Docker 镜像（从你的仓库或重新构建）
docker pull your-registry/strongswan-gmssl:3.1.1
# 或者上传镜像
# docker load < strongswan-gmssl-3.1.1.tar

# 运行客户端容器
docker run -d \
  --name strongswan-client \
  --privileged \
  --network host \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /var/log/strongswan-client:/var/log/strongswan \
  -e GMSSL_ENABLED=1 \
  your-registry/strongswan-gmssl:3.1.1

# 查看日志
docker logs -f strongswan-client

# 加载配置
docker exec strongswan-client swanctl --load-all

# 发起连接
docker exec strongswan-client swanctl --initiate --child gmsm-net

# 查看连接状态
docker exec strongswan-client swanctl --list-sas
```

---

### 方案 2：在 WSL2 中直接运行（次优选择）

**优点**：
- 不需要额外的服务器
- 可以在本地测试
- WSL2 网络配置相对简单

**缺点**：
- 需要配置 WSL2 网络
- 需要手动编译/安装 strongSwan

**步骤**：

#### 2.1 在 WSL2 中准备环境
```bash
# 进入 WSL2
wsl

cd /mnt/c/Code/strongswan

# 解压编译包（如果还没解压）
tar -xzf strongswan-gmssl-3.1.1.tar.gz
cd strongswan-gmssl-3.1.1

# 编译安装
./configure \
  --prefix=/usr/local/strongswan \
  --sysconfdir=/etc \
  --enable-swanctl \
  --disable-stroke \
  --enable-gmsm \
  --with-gmssl=/usr/local
make && sudo make install

# 复制配置
sudo mkdir -p /etc/swanctl
sudo cp /mnt/c/Code/strongswan/config/swanctl/gmsm-psk-client.conf /etc/swanctl/swanctl.conf

# 启动 charon
sudo /usr/local/strongswan/sbin/charon &

# 加载配置
sudo swanctl --load-all

# 发起连接
sudo swanctl --initiate --child gmsm-net

# 查看状态
sudo swanctl --list-sas
```

---

### 方案 3：使用端口映射（不推荐，但可验证基础功能）

**缺点**：
- IKE 协议对 NAT 支持有限
- 可能需要 NAT-T 支持
- 不是真实的生产环境

**步骤**：

#### 3.1 修改 docker-compose.yml
```yaml
services:
  strongswan-client:
    image: strongswan-gmssl:3.1.1
    container_name: strongswan-client
    privileged: true
    # 移除 network_mode: host
    ports:
      - "500:500/udp"
      - "4500:4500/udp"
    volumes:
      - ./config/swanctl/gmsm-psk-client.conf:/etc/swanctl/swanctl.conf
    environment:
      - GMSSL_ENABLED=1
```

#### 3.2 获取 Windows 主机 IP
```powershell
# 获取 Windows 的公网 IP（如果在本地网络）
# 或者获取局域网 IP
ipconfig | Select-String "IPv4"
```

#### 3.3 修改客户端配置中的 local_addrs
需要设置为 Windows 主机的实际 IP。

---

## 测试步骤（以方案 1 为例）

### 第一阶段：标准算法测试

#### 服务器端配置（已部署）
```properties
# config/swanctl/gmsm-psk-server.conf
proposals = aes256-sha256-modp2048
esp_proposals = aes256-sha256
```

#### 客户端配置
```properties
# config/swanctl/gmsm-psk-client.conf
remote_addrs = 101.126.148.5
proposals = aes256-sha256-modp2048
esp_proposals = aes256-sha256
```

#### 验证步骤
```bash
# 1. 客户端发起连接
docker exec strongswan-client swanctl --initiate --child gmsm-net

# 2. 查看连接状态
docker exec strongswan-client swanctl --list-sas

# 3. 测试网络连通性
docker exec strongswan-client ping -c 4 10.10.10.1

# 4. 查看日志
docker exec strongswan-client tail -f /var/log/strongswan/charon.log
```

---

### 第二阶段：国密算法测试

#### 查看可用的 GMSM 算法
```bash
# 在服务器和客户端都运行
docker exec strongswan-gmsm swanctl --list-algs | grep -i "sm\|gm"
```

当前已知支持的算法：
- **Integrity**: HMAC_SM3_96
- **Hasher**: HASH_SM3
- **PRF**: PRF_HMAC_SM3
- **Encryption**: SM4 (编号 1031/1032)

#### 修改配置使用 GMSM 算法

**服务器端配置**：
```properties
connections {
    gmsm-psk-test {
        version = 2
        # IKE SA - 使用 GMSM 算法
        proposals = sm4-sm3-modp2048
        
        # ... 其他配置保持不变 ...
        
        children {
            gmsm-net {
                # ESP - 使用 GMSM 算法
                esp_proposals = sm4-sm3
                # ... 其他配置保持不变 ...
            }
        }
    }
}
```

**客户端配置**：
```properties
connections {
    gmsm-vpn {
        version = 2
        proposals = sm4-sm3-modp2048
        remote_addrs = 101.126.148.5
        
        # ... 其他配置保持不变 ...
        
        children {
            gmsm-net {
                esp_proposals = sm4-sm3
                # ... 其他配置保持不变 ...
            }
        }
    }
}
```

#### 部署并测试
```bash
# 1. 更新服务器配置
scp config/swanctl/gmsm-psk-server.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"

# 2. 更新客户端配置
scp config/swanctl/gmsm-psk-client.conf root@$CLIENT_IP:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@$CLIENT_IP "docker exec strongswan-client swanctl --load-all"

# 3. 发起连接
ssh root@$CLIENT_IP "docker exec strongswan-client swanctl --initiate --child gmsm-net"

# 4. 验证使用的算法
ssh root@$CLIENT_IP "docker exec strongswan-client swanctl --list-sas"
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-sas"
```

---

## 预期结果

### 标准算法测试成功标志
```
gmsm-vpn: #1, ESTABLISHED, IKEv2, <hash>
  local  'vpn-client@test.com' @ 客户端IP
  remote 'vpn-server@test.com' @ 101.126.148.5
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  established 1s ago, rekeying in 3599s
  gmsm-net: #1, reqid 1, INSTALLED, TUNNEL, ESP:AES_CBC-256/HMAC_SHA2_256_128
    installed 1s ago, rekeying in 3299s, expires in 3899s
    in  <bytes_in> bytes,  <packets_in> packets
    out <bytes_out> bytes, <packets_out> packets
```

### 国密算法测试成功标志
```
gmsm-vpn: #1, ESTABLISHED, IKEv2, <hash>
  local  'vpn-client@test.com' @ 客户端IP
  remote 'vpn-server@test.com' @ 101.126.148.5
  SM4/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
  established 1s ago, rekeying in 3599s
  gmsm-net: #1, reqid 1, INSTALLED, TUNNEL, ESP:SM4/HMAC_SM3_96
    installed 1s ago, rekeying in 3299s, expires in 3899s
    in  <bytes_in> bytes,  <packets_in> packets
    out <bytes_out> bytes, <packets_out> packets
```

---

## 常见问题排查

### 1. 连接超时
```bash
# 检查网络连通性
ping 101.126.148.5

# 检查 UDP 端口
nc -u -v 101.126.148.5 500
nc -u -v 101.126.148.5 4500

# 检查服务器防火墙
ssh root@101.126.148.5 "iptables -L -n | grep -E '500|4500'"
```

### 2. 算法不支持
```bash
# 查看详细日志
docker logs strongswan-client 2>&1 | grep -i "proposal\|algorithm"

# 确认插件加载
docker exec strongswan-client swanctl --stats
```

### 3. 认证失败
```bash
# 检查 PSK 配置
docker exec strongswan-client cat /etc/swanctl/swanctl.conf | grep -A 3 "secrets"
docker exec strongswan-gmsm cat /etc/swanctl/swanctl.conf | grep -A 3 "secrets"
```

---

## 快速测试脚本

### Windows PowerShell 脚本
```powershell
# test-gmsm-vpn-linux.ps1
# 在两台 Linux 服务器上测试 GMSM VPN

$SERVER_IP = "101.126.148.5"
$CLIENT_IP = "your.client.ip"  # 修改为实际的客户端 IP

Write-Host "=== 部署服务器配置 ===" -ForegroundColor Green
scp config/swanctl/gmsm-psk-server.conf root@${SERVER_IP}:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@$SERVER_IP "docker exec strongswan-gmsm swanctl --load-all"

Write-Host "`n=== 部署客户端配置 ===" -ForegroundColor Green
scp config/swanctl/gmsm-psk-client.conf root@${CLIENT_IP}:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@$CLIENT_IP "docker exec strongswan-client swanctl --load-all"

Write-Host "`n=== 发起连接 ===" -ForegroundColor Green
ssh root@$CLIENT_IP "docker exec strongswan-client swanctl --initiate --child gmsm-net"

Start-Sleep -Seconds 3

Write-Host "`n=== 查看客户端状态 ===" -ForegroundColor Green
ssh root@$CLIENT_IP "docker exec strongswan-client swanctl --list-sas"

Write-Host "`n=== 查看服务器状态 ===" -ForegroundColor Green
ssh root@$SERVER_IP "docker exec strongswan-gmsm swanctl --list-sas"

Write-Host "`n=== 测试连通性 ===" -ForegroundColor Green
ssh root@$CLIENT_IP "docker exec strongswan-client ping -c 4 10.10.10.1"
```

---

## 总结

### Windows Docker Desktop 的限制
1. `network_mode: host` 在 Windows 上无效
2. 容器获得的是 WSL2 内部 IP
3. 远程服务器无法路由回该 IP
4. **不适合用于 IPsec VPN 客户端测试**

### 推荐的测试环境
1. **生产环境**：Linux 服务器 + Linux 客户端
2. **开发环境**：WSL2 直接安装 strongSwan
3. **备选方案**：使用云服务器作为客户端测试

### 下一步行动
- [ ] 准备第二台 Linux 服务器作为客户端
- [ ] 上传 Docker 镜像到客户端
- [ ] 执行标准算法测试
- [ ] 执行国密算法测试
- [ ] 记录测试结果和性能数据

