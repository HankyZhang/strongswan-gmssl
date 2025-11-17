# 云服务器部署命令

## 准备工作

已完成：
- ✅ Docker 镜像已导出：`strongswan-gmssl.tar.gz` (61.06 MB)
- ✅ 部署脚本已就绪：`deployment-scripts/deploy-server.sh` 和 `deploy-client.sh`
- ✅ 所有文档已完成

## 第一步：上传文件到云服务器

### 上传到服务器端 (101.126.148.5)

```bash
# 从本地机器执行
scp strongswan-gmssl.tar.gz root@101.126.148.5:~/
scp deployment-scripts/deploy-server.sh root@101.126.148.5:~/
```

### 上传到客户端 (8.140.37.32)

```bash
# 从本地机器执行
scp strongswan-gmssl.tar.gz root@8.140.37.32:~/
scp deployment-scripts/deploy-client.sh root@8.140.37.32:~/
```

## 第二步：部署服务器端 (101.126.148.5)

```bash
# SSH 登录到服务器
ssh root@101.126.148.5

# 解压并加载 Docker 镜像
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar

# 给脚本添加执行权限并运行
chmod +x deploy-server.sh
./deploy-server.sh

# 等待脚本完成，应该看到：
# ✅ Container started successfully
# ✅ CA certificate generated
# ✅ Server certificate generated  
# ✅ Client certificate generated
# ✅ All credentials loaded successfully

# 验证容器运行状态
docker ps | grep strongswan-server

# 验证证书已加载
docker exec strongswan-server swanctl --list-certs

# 验证连接配置已加载
docker exec strongswan-server swanctl --list-conns
```

## 第三步：导出客户端证书

```bash
# 在服务器端 (101.126.148.5) 执行
docker exec strongswan-server cat /tmp/ca.pem > ca.pem
docker exec strongswan-server cat /tmp/client.crt > client.crt
docker exec strongswan-server cat /tmp/client-key.pem > client-key.pem

# 验证文件已导出
ls -lh *.pem *.crt

# 从服务器传输到客户端
scp ca.pem client.crt client-key.pem root@8.140.37.32:~/
```

## 第四步：部署客户端 (8.140.37.32)

```bash
# SSH 登录到客户端
ssh root@8.140.37.32

# 解压并加载 Docker 镜像（如果之前未上传）
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar

# 确认证书文件已存在
ls -lh ca.pem client.crt client-key.pem

# 给脚本添加执行权限并运行
chmod +x deploy-client.sh
./deploy-client.sh

# 等待脚本完成，应该看到：
# ✅ Container started successfully
# ✅ Certificates installed successfully
# ✅ All credentials loaded successfully

# 验证容器运行状态
docker ps | grep strongswan-client

# 验证证书已加载
docker exec strongswan-client swanctl --list-certs

# 验证连接配置已加载
docker exec strongswan-client swanctl --list-conns
```

## 第五步：建立 IKEv2 连接

```bash
# 在客户端 (8.140.37.32) 执行
docker exec strongswan-client swanctl --initiate --child client-tunnel

# 期望输出类似：
# [IKE] initiating IKE_SA client-sm2[1] to 101.126.148.5
# [IKE] IKE_SA client-sm2[1] established
# [IKE] scheduling rekeying in XXXs
# [CHD] CHILD_SA client-tunnel{1} established
```

## 第六步：验证连接

### 在客户端验证

```bash
# 查看 IKE SA 状态
docker exec strongswan-client swanctl --list-sas

# 查看 CHILD SA 状态
docker exec strongswan-client swanctl --list-sas --ike-id 1

# 查看日志确认使用 SM2/SM3/SM4
docker logs strongswan-client | grep -E "SM2|SM3|SM4|selected proposal"

# 测试隧道连通性（从客户端 ping 服务器端隧道地址）
docker exec strongswan-client ping -c 4 10.10.0.1
```

### 在服务器端验证

```bash
# SSH 到服务器 (101.126.148.5)
ssh root@101.126.148.5

# 查看 IKE SA 状态
docker exec strongswan-server swanctl --list-sas

# 查看日志确认使用 SM2/SM3/SM4
docker logs strongswan-server | grep -E "SM2|SM3|SM4|selected proposal"

# 测试隧道连通性（从服务器 ping 客户端隧道地址）
docker exec strongswan-server ping -c 4 10.20.0.1
```

## 第七步：收集测试数据

```bash
# 在客户端执行
docker exec strongswan-client swanctl --list-sas --ike-id 1 > test-results-client.txt
docker logs strongswan-client 2>&1 | tail -100 >> test-results-client.txt

# 在服务器端执行
docker exec strongswan-server swanctl --list-sas --ike-id 1 > test-results-server.txt
docker logs strongswan-server 2>&1 | tail -100 >> test-results-server.txt

# 下载到本地
scp root@8.140.37.32:~/test-results-client.txt ./
scp root@101.126.148.5:~/test-results-server.txt ./
```

## 故障排除

### 如果连接失败

1. **检查防火墙规则**
   ```bash
   # 确保服务器安全组开放了以下端口：
   # - UDP 500 (IKE)
   # - UDP 4500 (NAT-T)
   # - IP Protocol 50 (ESP)
   ```

2. **检查容器日志**
   ```bash
   # 客户端
   docker logs strongswan-client -f
   
   # 服务器端
   docker logs strongswan-server -f
   ```

3. **重新加载配置**
   ```bash
   # 在客户端
   docker exec strongswan-client swanctl --load-all
   
   # 在服务器端
   docker exec strongswan-server swanctl --load-all
   ```

4. **重启容器**
   ```bash
   # 客户端
   docker restart strongswan-client
   
   # 服务器端
   docker restart strongswan-server
   ```

## 成功标准

✅ **IKE SA 建立成功**
- 状态显示：ESTABLISHED
- 加密套件：SM4GCM-PRF_SM3-MODP_2048

✅ **CHILD SA 建立成功**
- 状态显示：INSTALLED
- ESP 加密：SM4_GCM_16

✅ **证书验证成功**
- 日志显示：authentication of 'C=CN, O=VPN Server, CN=vpn-server-101.126.148.5' with SM2 signature successful
- 日志显示：authentication of 'C=CN, O=VPN Client, CN=vpn-client-8.140.37.32' with SM2 signature successful

✅ **隧道连通性**
- 客户端可以 ping 通 10.10.0.1
- 服务器端可以 ping 通 10.20.0.1

## 快速参考

**服务器 IP**: 101.126.148.5  
**客户端 IP**: 8.140.37.32  
**服务器隧道网段**: 10.10.0.0/24  
**客户端隧道网段**: 10.20.0.0/24  
**证书密码**: 123456  
**连接名称**: server-sm2 (服务器) / client-sm2 (客户端)  
**隧道名称**: server-tunnel (服务器) / client-tunnel (客户端)

## 相关文档

- 快速开始指南：`CLOUD-QUICK-START.md`
- 完整部署指南：`docs/CLOUD-DEPLOYMENT-GUIDE.md`
- 部署检查清单：`DEPLOYMENT-CHECKLIST.md`
- 技术摘要：`CLOUD-TEST-SUMMARY.md`
