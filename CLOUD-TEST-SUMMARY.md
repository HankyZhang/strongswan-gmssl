# 云服务器 IKEv2 SM2/SM3/SM4 VPN 测试摘要

## 📋 测试配置

### 服务器信息
- **服务器IP**: 101.126.148.5  
- **客户端IP**: 8.140.37.32  
- **VPN协议**: IKEv2  
- **加密算法**: SM4-GCM-16  
- **哈希算法**: PRF-SM3  
- **签名算法**: SM2 (国密椭圆曲线)  
- **密钥交换**: MODP-2048

### 隧道配置
```
服务器端网段: 10.10.0.0/24
客户端网段:   10.20.0.0/24
```

## 🚀 部署流程

### 1. 准备阶段 (本地开发机)

```powershell
# 克隆仓库
git clone https://github.com/HankyZhang/strongswan-gmssl.git
cd strongswan-gmssl

# 运行预部署测试
.\test-predeploy.ps1

# 导出镜像
docker save strongswan-gmssl:latest -o strongswan-gmssl.tar
gzip strongswan-gmssl.tar

# 上传到云服务器
scp strongswan-gmssl.tar.gz root@101.126.148.5:~/
scp strongswan-gmssl.tar.gz root@8.140.37.32:~/

# 上传部署脚本
scp deployment-scripts/deploy-server.sh root@101.126.148.5:~/
scp deployment-scripts/deploy-client.sh root@8.140.37.32:~/
```

### 2. 服务器部署 (101.126.148.5)

```bash
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

### 3. 客户端部署 (8.140.37.32)

```bash
ssh root@8.140.37.32

# 加载镜像
gunzip strongswan-gmssl.tar.gz
docker load -i strongswan-gmssl.tar

# 运行部署脚本 (会自动使用传输过来的证书)
chmod +x deploy-client.sh
./deploy-client.sh
```

### 4. 发起连接测试

```bash
# 从客户端发起连接
docker exec strongswan-client swanctl --initiate --child client-tunnel

# 查看连接状态
docker exec strongswan-client swanctl --list-sas
```

## ✅ 成功标准

连接成功后，应看到以下输出：

```
client-sm2: #1, ESTABLISHED, IKEv2
  local  'C=CN, O=VPN Client, CN=vpn-client-8.140.37.32' @ 8.140.37.32[500]
  remote 'C=CN, O=VPN Server, CN=vpn-server-101.126.148.5' @ 101.126.148.5[500]
  SM4_GCM_16/PRF_SM3/MODP_2048
  established 10s ago, rekeying in 3h59m50s
  client-tunnel: #1, reqid 1, INSTALLED, TUNNEL, ESP:SM4_GCM_16
    installed 10s ago, rekeying in 59m50s, expires in 1h
    in  c12345678,      0 bytes,     0 packets
    out c87654321,      0 bytes,     0 packets
    local  10.20.0.0/24
    remote 10.10.0.0/24
```

关键验证点：
- ✅ IKE SA 状态: `ESTABLISHED`
- ✅ 加密套件: `SM4_GCM_16/PRF_SM3/MODP_2048`
- ✅ CHILD SA 状态: `INSTALLED`
- ✅ ESP 算法: `ESP:SM4_GCM_16`
- ✅ 使用 SM2 证书认证

## 📊 技术验证

### 已实现的国密算法集成

1. **SM2 椭圆曲线密钥对**
   - 证书公钥: SM2 256 bits
   - 私钥加密: PKCS#8 with password
   - 签名算法: SM2-with-SM3

2. **SM3 哈希函数**
   - IKE PRF: PRF_SM3
   - 证书签名: sm2sign-with-sm3

3. **SM4 对称加密**
   - IKE加密: SM4-GCM-16
   - ESP加密: SM4-GCM-16
   - 认证加密一体(AEAD)

### strongSwan 集成点

**新增文件** (Build 1-12):
```
src/libstrongswan/plugins/gmsm/
├── gmsm_plugin.c                 # 插件注册
├── gmsm_sm2_public_key.c         # SM2公钥操作
├── gmsm_sm2_private_key.c        # SM2私钥操作 (Build 9-12: 密码数组)
├── gmsm_sm3_hasher.c             # SM3哈希
├── gmsm_sm3_prf.c                # SM3 PRF
├── gmsm_sm4_crypter.c            # SM4加密
└── gmsm_proposal.c               # 算法提议
```

**修改文件**:
```
src/libstrongswan/plugins/x509/x509_cert.c
  - Build 8: 添加SM2 OID fallback解析
  
src/libcharon/plugins/vici/vici_cred.c
  - Build 12: 放松CA约束检查 (GmSSL限制workaround)
```

### 关键突破

**Build 8** (证书解析):
- 解决 SM2 OID 识别问题
- 实现 fallback 机制

**Build 9** (私钥解密):
- 发现原始密钥使用空密码
- 实现密码数组尝试机制

**Build 12** (完整加载):
- 放松CA basicConstraints检查
- GmSSL HMAC bug workaround
- 证书链完整加载成功

## 🔧 故障排查快速参考

### 连接超时
```bash
# 检查安全组: UDP 500, 4500, ESP(50)
# 检查服务器监听
docker exec strongswan-server netstat -ulnp | grep 500

# 测试连通性
nc -u -v 101.126.148.5 500
```

### 证书问题
```bash
# 查看已加载证书
docker exec strongswan-client swanctl --list-certs

# 查看证书CN
docker exec strongswan-client swanctl --list-certs | grep "subject:"
```

### 日志分析
```bash
# 实时日志
docker exec strongswan-client tail -f /var/log/charon.log

# 过滤关键信息
docker exec strongswan-client grep -E "IKE|CHILD|ESP|SM2|SM3|SM4|ERROR" /var/log/charon.log | tail -50
```

## 📚 文档索引

- **快速开始**: `CLOUD-QUICK-START.md`
- **完整部署指南**: `docs/CLOUD-DEPLOYMENT-GUIDE.md`
- **服务器部署脚本**: `deployment-scripts/deploy-server.sh`
- **客户端部署脚本**: `deployment-scripts/deploy-client.sh`
- **配置文件**: `config/swanctl/swanctl.conf`
- **strongSwan配置**: `config/strongswan.conf.gmsm`

## 🎯 测试目标

本次测试旨在验证：

1. ✅ SM2 证书生成和加载
2. ✅ SM2 签名算法在 IKE_AUTH 中的使用
3. ✅ SM3 哈希函数在 PRF 中的应用
4. ✅ SM4-GCM 在 IKE 和 ESP 中的加密
5. ⏳ **实际云环境的 IKEv2 连接建立**
6. ⏳ **国密算法性能测试**
7. ⏳ **长时间稳定性验证**

## 📈 预期成果

- **技术验证**: 证明 strongSwan 可完整集成国密算法
- **性能基准**: 建立 SM4-GCM 性能基线数据
- **部署模板**: 为后续项目提供可复制的部署方案
- **文档完善**: 形成完整的技术文档和故障排查手册

## 🔄 后续计划

1. 完成云服务器实测
2. 收集性能数据
3. 优化配置参数
4. 编写最终测试报告
5. 提交完整代码和文档

---

**当前状态**: 代码和配置已就绪，等待云服务器部署测试

**最后更新**: 2025-11-17 Build 12  
**Git提交**: cb614d45fe (Build 12), 59446ec2dd (Deployment scripts)
