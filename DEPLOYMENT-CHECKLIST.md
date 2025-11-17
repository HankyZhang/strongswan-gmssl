# 云服务器 IKEv2 部署清单

## ✅ 准备工作清单

### 本地开发机
- [x] strongSwan代码完成 (Build 12)
- [x] Docker镜像构建成功
- [x] 预部署测试通过
- [ ] 镜像导出: `docker save strongswan-gmssl:latest -o strongswan-gmssl.tar`
- [ ] 镜像压缩: `gzip strongswan-gmssl.tar`
- [ ] 上传到服务器 (101.126.148.5, 8.140.37.32)

### 云服务器 101.126.148.5 (服务器端)
- [ ] Docker 已安装
- [ ] 安全组开放: UDP 500, 4500, ESP(50)
- [ ] 防火墙配置正确
- [ ] 镜像已上传
- [ ] 部署脚本已上传 (`deploy-server.sh`)

### 云服务器 8.140.37.32 (客户端)
- [ ] Docker 已安装
- [ ] 安全组开放: UDP 500, 4500, ESP(50)
- [ ] 防火墙配置正确
- [ ] 镜像已上传
- [ ] 部署脚本已上传 (`deploy-client.sh`)

## 📝 部署步骤

### Step 1: 服务器部署 (101.126.148.5)

```bash
ssh root@101.126.148.5
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar
chmod +x deploy-server.sh
./deploy-server.sh
```

预期输出:
```
==========================================
Server deployment complete!
==========================================
```

### Step 2: 导出客户端证书

```bash
docker exec strongswan-server cat /tmp/ca.pem > ca.pem
docker exec strongswan-server cat /tmp/client.crt > client.crt  
docker exec strongswan-server cat /tmp/client-key.pem > client-key.pem
scp *.pem root@8.140.37.32:~/
```

### Step 3: 客户端部署 (8.140.37.32)

```bash
ssh root@8.140.37.32
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar
chmod +x deploy-client.sh
./deploy-client.sh
```

预期输出:
```
==========================================
Client deployment complete!
==========================================
```

### Step 4: 发起连接

```bash
docker exec strongswan-client swanctl --initiate --child client-tunnel
```

预期输出 (成功):
```
[IKE] establishing IKE_SA client-sm2[1] to 101.126.148.5
[CFG] selected proposal: IKE:SM4_GCM_16/PRF_SM3/MODP_2048
[IKE] authentication of '...' (myself) with SM2
[IKE] authentication of '...' with SM2 successful
[IKE] IKE_SA client-sm2[1] established
[IKE] CHILD_SA client-tunnel{1} established with SPIs ... and TS 10.20.0.0/24 === 10.10.0.0/24
initiate completed successfully
```

### Step 5: 验证连接

```bash
# 查看 SA 状态
docker exec strongswan-client swanctl --list-sas

# 查看日志
docker exec strongswan-client tail -50 /var/log/charon.log | grep -E "ESTABLISHED|SM2|SM3|SM4"
```

## 🎯 验证点

### IKE SA 验证
- [ ] 状态: ESTABLISHED
- [ ] 算法: SM4_GCM_16/PRF_SM3/MODP_2048
- [ ] 本地ID: C=CN, O=VPN Client, CN=vpn-client-8.140.37.32
- [ ] 远程ID: C=CN, O=VPN Server, CN=vpn-server-101.126.148.5
- [ ] 认证: SM2 certificates

### CHILD SA 验证
- [ ] 状态: INSTALLED
- [ ] 算法: ESP:SM4_GCM_16
- [ ] 本地TS: 10.20.0.0/24
- [ ] 远程TS: 10.10.0.0/24
- [ ] 有 in/out 包计数

### 日志验证
- [ ] 无 ERROR 或 WARNING
- [ ] 看到 "SM2" 签名成功
- [ ] 看到 "SM4_GCM_16" 加密协商
- [ ] 看到 "PRF_SM3" PRF 算法

## 📊 测试数据收集

### 连接建立时间
```bash
# 记录时间戳
date && docker exec strongswan-client swanctl --initiate --child client-tunnel && date
```

测试结果: ___ 秒

### 重连测试
```bash
# 断开
docker exec strongswan-client swanctl --terminate --ike client-sm2

# 等待5秒
sleep 5

# 重连
docker exec strongswan-client swanctl --initiate --child client-tunnel
```

重连成功: [ ] 是 [ ] 否

### 稳定性测试
```bash
# 保持连接1小时
docker exec strongswan-client swanctl --list-sas
# 每10分钟检查一次状态
```

1小时后状态: [ ] 仍然 ESTABLISHED [ ] 断开

## 🐛 故障排查

如果连接失败，依次检查：

1. **网络连通性**
   ```bash
   ping 101.126.148.5
   nc -u -v 101.126.148.5 500
   ```

2. **服务器状态**
   ```bash
   docker ps | grep strongswan-server
   docker exec strongswan-server netstat -ulnp | grep 500
   ```

3. **证书加载**
   ```bash
   docker exec strongswan-client swanctl --list-certs | grep "has private key"
   ```

4. **配置检查**
   ```bash
   docker exec strongswan-client swanctl --list-conns
   ```

5. **详细日志**
   ```bash
   docker exec strongswan-client tail -100 /var/log/charon.log
   docker exec strongswan-server tail -100 /var/log/charon.log
   ```

## 📸 截图和日志

需要保存的内容：

1. [ ] `swanctl --list-sas` 完整输出
2. [ ] `swanctl --list-certs` 完整输出
3. [ ] charon.log 中的 IKE_SA_INIT 和 IKE_AUTH 消息
4. [ ] 连接建立时的时间戳
5. [ ] 算法协商的详细信息

## 🎉 成功标准

所有以下条件满足即为成功：

- [x] 服务器容器正常运行
- [x] 客户端容器正常运行
- [ ] IKE SA 成功建立
- [ ] CHILD SA 成功建立
- [ ] 使用 SM2/SM3/SM4 算法
- [ ] 无错误日志
- [ ] 连接稳定

## 📋 报告模板

```
=== strongSwan SM2/SM3/SM4 VPN 测试报告 ===

测试日期: ____
测试人员: ____

服务器: 101.126.148.5
客户端: 8.140.37.32

IKE SA 状态: [ ] ESTABLISHED [ ] FAILED
  - 算法: ____
  - 建立时间: ____ 秒

CHILD SA 状态: [ ] INSTALLED [ ] FAILED
  - 算法: ____
  - 隧道: 10.20.0.0/24 <=> 10.10.0.0/24

SM2 证书认证: [ ] 成功 [ ] 失败
SM3 PRF: [ ] 使用 [ ] 未使用
SM4-GCM 加密: [ ] 使用 [ ] 未使用

连接稳定性:
  - 初次连接: [ ] 成功 [ ] 失败
  - 重连测试: [ ] 成功 [ ] 失败
  - 1小时稳定性: [ ] 通过 [ ] 失败

问题记录:
____

建议改进:
____

结论: [ ] 测试通过 [ ] 需要改进
```

## 📞 联系方式

如有问题，参考以下文档：
- `CLOUD-QUICK-START.md` - 快速开始
- `docs/CLOUD-DEPLOYMENT-GUIDE.md` - 完整指南
- `CLOUD-TEST-SUMMARY.md` - 技术摘要

---

**准备人**: GitHub Copilot  
**版本**: Build 12  
**日期**: 2025-11-17
