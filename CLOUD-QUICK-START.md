# 云服务器 IKEv2 部署快速开始

## 🚀 一键测试与部署

### 本地准备（开发机器）

```powershell
# 1. 运行预部署测试
.\test-predeploy.ps1

# 2. 导出镜像
docker save strongswan-gmssl:latest -o strongswan-gmssl.tar
gzip strongswan-gmssl.tar

# 3. 上传镜像到服务器
scp strongswan-gmssl.tar.gz root@101.126.148.5:~/
scp strongswan-gmssl.tar.gz root@8.140.37.32:~/

# 4. 上传部署脚本
scp deployment-scripts/deploy-server.sh root@101.126.148.5:~/
scp deployment-scripts/deploy-client.sh root@8.140.37.32:~/
```

### 服务器部署 (101.126.148.5)

```bash
# SSH 登录
ssh root@101.126.148.5

# 加载镜像
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar

# 运行部署脚本
chmod +x deploy-server.sh
./deploy-server.sh

# 导出客户端证书
docker exec strongswan-server cat /tmp/ca.pem > ca.pem
docker exec strongswan-server cat /tmp/client.crt > client.crt
docker exec strongswan-server cat /tmp/client-key.pem > client-key.pem

# 传输到客户端
scp *.pem root@8.140.37.32:~/
```

### 客户端部署 (8.140.37.32)

```bash
# SSH 登录
ssh root@8.140.37.32

# 加载镜像
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar

# 运行部署脚本
chmod +x deploy-client.sh
./deploy-client.sh

# 发起 VPN 连接
docker exec strongswan-client swanctl --initiate --child client-tunnel

# 查看连接状态
docker exec strongswan-client swanctl --list-sas
```

## 🔍 验证连接

### 预期成功输出

```
client-sm2: #1, ESTABLISHED, IKEv2
  local  'C=CN, O=VPN Client, CN=vpn-client-8.140.37.32' @ 8.140.37.32[500]
  remote 'C=CN, O=VPN Server, CN=vpn-server-101.126.148.5' @ 101.126.148.5[500]
  SM4_GCM_16/PRF_SM3/MODP_2048
  established 10s ago
  client-tunnel: #1, reqid 1, INSTALLED, TUNNEL, ESP:SM4_GCM_16
    local  10.20.0.0/24
    remote 10.10.0.0/24
```

关键指标：
- ✅ IKE SA 状态: `ESTABLISHED`
- ✅ IKE 算法: `SM4_GCM_16/PRF_SM3/MODP_2048`
- ✅ ESP 算法: `ESP:SM4_GCM_16`
- ✅ 认证方式: SM2 证书

## 📚 详细文档

完整部署指南请参考: [docs/CLOUD-DEPLOYMENT-GUIDE.md](docs/CLOUD-DEPLOYMENT-GUIDE.md)

包含内容：
- 安全组配置详解
- 故障排查步骤
- 性能测试方法
- 日志分析指南

## ⚠️ 重要提示

### 云服务器安全组配置

**必须**在两台服务器的安全组中开放：
- UDP 500 (IKE)
- UDP 4500 (NAT-T)
- ESP 协议 (IP Protocol 50)

### 防火墙配置

如果服务器启用了 firewalld 或 iptables：

```bash
# firewalld
sudo firewall-cmd --permanent --add-service=ipsec
sudo firewall-cmd --reload

# iptables
sudo iptables -A INPUT -p udp --dport 500 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 4500 -j ACCEPT
sudo iptables -A INPUT -p esp -j ACCEPT
```

## 🛠 快速命令

### 查看状态
```bash
# SA 列表
docker exec strongswan-client swanctl --list-sas

# 证书列表
docker exec strongswan-client swanctl --list-certs

# 连接配置
docker exec strongswan-client swanctl --list-conns
```

### 操作连接
```bash
# 发起连接
docker exec strongswan-client swanctl --initiate --child client-tunnel

# 断开连接
docker exec strongswan-client swanctl --terminate --ike client-sm2

# 重新加载配置
docker exec strongswan-client swanctl --load-all
```

### 查看日志
```bash
# 实时日志
docker exec strongswan-client tail -f /var/log/charon.log

# 过滤关键信息
docker exec strongswan-client grep -E "IKE|CHILD|ESP|SM2|SM3|SM4" /var/log/charon.log | tail -50
```

## 🎯 成功标准

IKEv2 连接成功的标志：

1. ✅ `swanctl --list-sas` 显示 `ESTABLISHED`
2. ✅ 使用的算法包含 SM4_GCM_16, PRF_SM3, SM2
3. ✅ CHILD SA 状态为 `INSTALLED`
4. ✅ 可以看到 in/out 数据包统计
5. ✅ 日志中无 ERROR 或 WARNING

## 📞 故障排查

### 连接超时
```bash
# 检查监听端口
docker exec strongswan-server netstat -ulnp | grep 500

# 测试网络连通
nc -u -v 101.126.148.5 500

# 检查日志
docker exec strongswan-server tail -100 /var/log/charon.log | grep received
```

### 证书问题
```bash
# 验证证书加载
docker exec strongswan-client swanctl --list-certs | grep "has private key"

# 查看证书详情
docker exec strongswan-client swanctl --list-certs | grep -A10 "subject:"
```

## 📈 性能测试

```bash
# 添加测试 IP
docker exec strongswan-server ip addr add 10.10.0.1/24 dev lo
docker exec strongswan-client ip addr add 10.20.0.1/24 dev lo

# Ping 测试
docker exec strongswan-client ping -c 10 10.10.0.1

# 延迟统计
docker exec strongswan-client ping -c 100 10.10.0.1 | tail -4
```

## 🔄 持续运行

容器已配置 `--restart unless-stopped`，会在以下情况自动重启：
- 进程崩溃
- 服务器重启

检查容器运行时间：
```bash
docker ps | grep strongswan
```

## ⚡ 下一步

连接成功后，您可以：

1. **配置应用流量路由**到 VPN 隧道
2. **添加更多网段**到 tunnel 配置
3. **启用日志归档**和监控
4. **性能调优**: MTU、offload、算法优先级
5. **高可用配置**: 双服务器、故障转移

---

**技术支持**: 查看 [docs/CLOUD-DEPLOYMENT-GUIDE.md](docs/CLOUD-DEPLOYMENT-GUIDE.md) 获取完整文档
