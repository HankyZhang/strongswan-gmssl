# strongSwan SM2/SM3/SM4 VPN 部署测试指南

## 环境信息

- **服务器**: 101.126.148.5 (阿里云/腾讯云 ECS)
- **客户端**: 8.140.37.32 (阿里云/腾讯云 ECS)
- **协议**: IKEv2 with SM2 certificates, SM3 hash, SM4-GCM encryption
- **隧道网段**: 
  - 服务器: 10.10.0.0/24
  - 客户端: 10.20.0.0/24

## 前置条件

### 1. 云服务器安全组配置

确保两台服务器的安全组开放以下端口：

```
UDP 500  (IKE)
UDP 4500 (NAT-T)
ESP Protocol (IP Protocol 50)
```

**阿里云安全组规则示例**:
```
规则方向: 入方向
授权策略: 允许
协议类型: UDP
端口范围: 500/500
授权对象: 对端服务器IP或 0.0.0.0/0

规则方向: 入方向
授权策略: 允许
协议类型: UDP
端口范围: 4500/4500
授权对象: 对端服务器IP或 0.0.0.0/0

规则方向: 入方向
授权策略: 允许
协议类型: ESP(50)
授权对象: 对端服务器IP或 0.0.0.0/0
```

### 2. Docker 安装

两台服务器都需要安装 Docker:

```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl enable docker
sudo systemctl start docker

# 验证安装
docker --version
```

### 3. 镜像准备

在本地构建镜像并导出：

```bash
# 在开发机器上
cd c:\Code\strongswan
docker build -f Dockerfile.gmssl -t strongswan-gmssl:latest .
docker save strongswan-gmssl:latest -o strongswan-gmssl.tar

# 压缩以便传输
gzip strongswan-gmssl.tar
```

将 `strongswan-gmssl.tar.gz` 传输到两台服务器：

```bash
# 从本地上传到服务器
scp strongswan-gmssl.tar.gz root@101.126.148.5:~/
scp strongswan-gmssl.tar.gz root@8.140.37.32:~/

# 在服务器上加载镜像
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar
docker images | grep strongswan-gmssl
```

## 部署步骤

### 第一步: 部署服务器端 (101.126.148.5)

```bash
# SSH 登录到服务器
ssh root@101.126.148.5

# 创建部署目录
mkdir -p ~/strongswan-deploy
cd ~/strongswan-deploy

# 上传部署脚本
# (从本地上传 deployment-scripts/deploy-server.sh)

# 赋予执行权限
chmod +x deploy-server.sh

# 执行部署
./deploy-server.sh
```

**预期输出**:
```
==========================================
Deploying strongSwan Server - SM2/SM3/SM4
Server IP: 101.126.148.5
Client IP: 8.140.37.32
==========================================
[1/6] Cleaning up existing containers...
[2/6] Loading strongSwan image...
[3/6] Starting strongSwan server container...
[4/6] Waiting for charon to start...
[5/6] Generating SM2 certificates...
Server certificates installed
[6/6] Loading credentials and connections...
loaded certificate from '/etc/swanctl/x509/servercert.pem'
loaded certificate from '/etc/swanctl/x509ca/cacert.pem'
loaded SM2 key from '/etc/swanctl/private/serverkey.pem'
loaded connection 'server-sm2'
==========================================
Server deployment complete!
==========================================
```

### 第二步: 导出客户端证书

在服务器上执行：

```bash
cd ~/strongswan-deploy

# 导出证书
docker exec strongswan-server cat /tmp/ca.pem > ca.pem
docker exec strongswan-server cat /tmp/client.crt > client.crt
docker exec strongswan-server cat /tmp/client-key.pem > client-key.pem

# 验证文件
ls -lh ca.pem client.crt client-key.pem
```

### 第三步: 传输证书到客户端

从服务器传输到客户端：

```bash
# 在服务器上执行
scp ca.pem client.crt client-key.pem root@8.140.37.32:~/strongswan-deploy/
```

或者从本地中转：

```bash
# 从服务器下载到本地
scp root@101.126.148.5:~/strongswan-deploy/*.pem .

# 从本地上传到客户端
scp *.pem root@8.140.37.32:~/strongswan-deploy/
```

### 第四步: 部署客户端 (8.140.37.32)

```bash
# SSH 登录到客户端
ssh root@8.140.37.32

# 创建部署目录
mkdir -p ~/strongswan-deploy
cd ~/strongswan-deploy

# 确认证书已就位
ls -lh ca.pem client.crt client-key.pem

# 上传部署脚本
# (从本地上传 deployment-scripts/deploy-client.sh)

# 赋予执行权限
chmod +x deploy-client.sh

# 执行部署
./deploy-client.sh
```

**预期输出**:
```
==========================================
Deploying strongSwan Client - SM2/SM3/SM4
Client IP: 8.140.37.32
Server IP: 101.126.148.5
==========================================
[1/5] Cleaning up existing containers...
[2/5] Starting strongSwan client container...
[3/5] Waiting for charon to start...
[4/5] Installing client certificates...
[5/5] Loading credentials and connections...
loaded certificate from '/etc/swanctl/x509/clientcert.pem'
loaded certificate from '/etc/swanctl/x509ca/cacert.pem'
loaded SM2 key from '/etc/swanctl/private/clientkey.pem'
loaded connection 'client-sm2'
==========================================
Client deployment complete!
==========================================
```

## VPN 连接测试

### 1. 从客户端发起连接

```bash
# 在客户端 (8.140.37.32) 上执行
docker exec strongswan-client swanctl --initiate --child client-tunnel
```

**成功连接的输出示例**:
```
[IKE] establishing IKE_SA client-sm2[1] to 101.126.148.5
[ENC] generating IKE_SA_INIT request 0 [ SA KE No N(NATD_S_IP) N(NATD_D_IP) N(FRAG_SUP) N(HASH_ALG) N(REDIR_SUP) ]
[NET] sending packet: from 8.140.37.32[500] to 101.126.148.5[500]
[NET] received packet: from 101.126.148.5[500] to 8.140.37.32[500]
[ENC] parsed IKE_SA_INIT response 0 [ SA KE No N(NATD_S_IP) N(NATD_D_IP) N(HASH_ALG) ]
[CFG] selected proposal: IKE:SM4_GCM_16/PRF_SM3/MODP_2048
[IKE] authentication of 'C=CN, O=VPN Client, CN=vpn-client-8.140.37.32' (myself) with SM2
[IKE] establishing CHILD_SA client-tunnel{1}
[ENC] generating IKE_AUTH request 1 [ IDi AUTH SA TSi TSr ]
[NET] sending packet: from 8.140.37.32[500] to 101.126.148.5[500]
[NET] received packet: from 101.126.148.5[500] to 8.140.37.32[500]
[ENC] parsed IKE_AUTH response 1 [ IDr AUTH SA TSi TSr ]
[IKE] authentication of 'C=CN, O=VPN Server, CN=vpn-server-101.126.148.5' with SM2 successful
[IKE] IKE_SA client-sm2[1] established between 8.140.37.32[C=CN, O=VPN Client, CN=vpn-client-8.140.37.32]...101.126.148.5[C=CN, O=VPN Server, CN=vpn-server-101.126.148.5]
[IKE] CHILD_SA client-tunnel{1} established with SPIs c12345678_i c87654321_o and TS 10.20.0.0/24 === 10.10.0.0/24
initiate completed successfully
```

### 2. 查看连接状态

在客户端查看：
```bash
docker exec strongswan-client swanctl --list-sas
```

在服务器查看：
```bash
docker exec strongswan-server swanctl --list-sas
```

**成功建立的 SA 示例**:
```
client-sm2: #1, ESTABLISHED, IKEv2, <SM2 fingerprint>
  local  'C=CN, O=VPN Client, CN=vpn-client-8.140.37.32' @ 8.140.37.32[500]
  remote 'C=CN, O=VPN Server, CN=vpn-server-101.126.148.5' @ 101.126.148.5[500]
  SM4_GCM_16/PRF_SM3/MODP_2048
  established 15s ago, rekeying in 3h45m
  client-tunnel: #1, reqid 1, INSTALLED, TUNNEL, ESP:SM4_GCM_16
    installed 15s ago, rekeying in 45m, expires in 1h
    in  c12345678,    120 bytes,     2 packets
    out c87654321,    120 bytes,     2 packets
    local  10.20.0.0/24
    remote 10.10.0.0/24
```

### 3. 配置虚拟 IP (可选)

如果需要测试隧道内通信，在两台服务器上添加虚拟接口：

```bash
# 在服务器 (101.126.148.5) 上
docker exec strongswan-server ip addr add 10.10.0.1/24 dev lo
docker exec strongswan-server ip link set lo up

# 在客户端 (8.140.37.32) 上
docker exec strongswan-client ip addr add 10.20.0.1/24 dev lo
docker exec strongswan-client ip link set lo up
```

### 4. 测试隧道通信

从客户端 ping 服务器的隧道 IP：

```bash
docker exec strongswan-client ping -c 4 10.10.0.1
```

从服务器 ping 客户端的隧道 IP：

```bash
docker exec strongswan-server ping -c 4 10.20.0.1
```

## 日志查看和调试

### 实时查看 charon 日志

客户端：
```bash
docker exec strongswan-client tail -f /var/log/charon.log
```

服务器：
```bash
docker exec strongswan-server tail -f /var/log/charon.log
```

### 查看最近的连接尝试

```bash
docker exec strongswan-client tail -100 /var/log/charon.log | grep -E 'IKE|CHILD|ESP|SM2|SM3|SM4'
```

### 抓包分析 (如果需要)

在服务器上：
```bash
docker exec strongswan-server tcpdump -i any -n port 500 or port 4500 -w /tmp/ipsec.pcap
```

下载并用 Wireshark 分析：
```bash
docker cp strongswan-server:/tmp/ipsec.pcap ./
```

## 验证加密算法

在建立连接后，验证使用的算法：

```bash
# 查看 IKE SA 算法
docker exec strongswan-client swanctl --list-sas | grep -E 'SM4|SM3|SM2|PRF'

# 查看 ESP SA 算法
docker exec strongswan-client swanctl --list-sas | grep -E 'ESP|SM4_GCM'
```

预期看到：
- IKE SA: `SM4_GCM_16/PRF_SM3/MODP_2048`
- CHILD SA: `ESP:SM4_GCM_16`
- 认证: `SM2` signatures

## 故障排查

### 1. 连接超时 (peer not responding)

**可能原因**:
- 安全组未开放 UDP 500/4500
- 服务器端未启动或未加载配置

**检查步骤**:
```bash
# 检查服务器容器状态
docker ps | grep strongswan-server

# 检查服务器是否监听 UDP 500
docker exec strongswan-server netstat -ulnp | grep 500

# 测试网络连通性
ping 101.126.148.5
nc -u -v 101.126.148.5 500
```

### 2. 证书验证失败

**可能原因**:
- 证书 CN 与配置的 ID 不匹配
- CA 证书未正确加载

**检查步骤**:
```bash
# 查看已加载的证书
docker exec strongswan-client swanctl --list-certs | grep -E 'subject:|issuer:'

# 查看配置的 ID
docker exec strongswan-client swanctl --list-conns | grep 'id:'
```

### 3. 私钥解密失败

**检查密码数组**:
```bash
# 查看日志中的密码尝试
docker exec strongswan-client grep "password attempt" /var/log/charon.log
docker exec strongswan-client grep "decrypted successfully" /var/log/charon.log
```

### 4. 算法协商失败

**可能原因**:
- strongswan.conf 中未启用 SM 算法插件

**检查步骤**:
```bash
# 查看已加载的插件
docker exec strongswan-client swanctl --version

# 查看提议列表
docker exec strongswan-client swanctl --list-conns | grep proposals
```

## 性能测试

### 1. 吞吐量测试

使用 iperf3 测试隧道吞吐量：

```bash
# 在服务器上启动 iperf3 server
docker exec strongswan-server iperf3 -s -B 10.10.0.1

# 在客户端运行测试
docker exec strongswan-client iperf3 -c 10.10.0.1 -B 10.20.0.1 -t 30
```

### 2. 延迟测试

```bash
docker exec strongswan-client ping -c 100 10.10.0.1 | tail -4
```

## 成功标准

✅ IKE_SA 成功建立，使用 SM2 证书认证  
✅ 协商算法为 SM4_GCM_16/PRF_SM3/MODP_2048  
✅ CHILD_SA 成功建立，使用 ESP:SM4_GCM_16  
✅ 隧道流量正常加密传输  
✅ 可以 ping 通对端隧道 IP  
✅ 日志中无错误或警告

## 后续优化

1. **配置自动重连**: 已在配置中启用 `dpd_action = restart`
2. **添加更多 proposals**: 支持降级到 SM4-CBC
3. **性能调优**: 调整 MTU、启用硬件加速
4. **监控告警**: 集成到监控系统

## 附录: 快速命令参考

```bash
# 服务器端常用命令
docker exec strongswan-server swanctl --list-sas
docker exec strongswan-server swanctl --list-certs
docker exec strongswan-server swanctl --list-conns
docker exec strongswan-server tail -50 /var/log/charon.log

# 客户端常用命令
docker exec strongswan-client swanctl --initiate --child client-tunnel
docker exec strongswan-client swanctl --list-sas
docker exec strongswan-client swanctl --terminate --ike client-sm2
docker exec strongswan-client tail -50 /var/log/charon.log

# 重启服务
docker restart strongswan-server
docker restart strongswan-client

# 查看资源使用
docker stats strongswan-server strongswan-client
```
