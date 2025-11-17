# SM2 国密算法完整集成验证报告

## 执行时间
**开始**: [待填写]  
**完成**: [待填写]

## 1. 构建验证

### 1.1 Docker 镜像构建
```powershell
docker build -f Dockerfile.gmssl -t strongswan-gmssl:latest .
```
- [ ] 构建成功（无编译错误）
- [ ] GmSSL 3.1.1 编译完成
- [ ] strongSwan 6.0.3dr1 编译完成
- [ ] gmsm 插件链接成功

### 1.2 容器启动
```powershell
docker rm -f strongswan-gmsm
docker run -d --name strongswan-gmsm --privileged strongswan-gmssl:latest /start.sh
sleep 6
```
- [ ] 容器成功启动
- [ ] charon 进程运行
- [ ] VICI socket 创建成功

## 2. 算法注册验证

```powershell
docker exec strongswan-gmsm swanctl --list-algs | grep -E "SM|HASH_SM3|PRF_HMAC_SM3"
```

**预期输出**:
- [ ] `SM4_CBC[gmsm]`
- [ ] `SM4_GCM_16[gmsm]`
- [ ] `HMAC_SM3_96[gmsm]`
- [ ] `HASH_SM3[gmsm]`
- [ ] `PRF_HMAC_SM3[gmsm]`
- [ ] `(1025)[gmsm]` (SM2_256 DH group)

## 3. SM2 证书加载验证

### 3.1 证书生成
```powershell
docker exec strongswan-gmsm ls -lh /etc/swanctl/x509ca/
docker exec strongswan-gmsm ls -lh /etc/swanctl/x509/
docker exec strongswan-gmsm ls -lh /etc/swanctl/private/
```

**预期文件**:
- [ ] `/etc/swanctl/x509ca/cacert.pem` (CA 证书)
- [ ] `/etc/swanctl/x509/servercert.pem` (服务器证书)
- [ ] `/etc/swanctl/x509/clientcert.pem` (客户端证书)
- [ ] `/etc/swanctl/private/serverkey.pem` (服务器私钥，加密)
- [ ] `/etc/swanctl/private/clientkey.pem` (客户端私钥，加密)

### 3.2 私钥解密测试
```powershell
docker exec strongswan-gmsm swanctl --load-creds
```

**验证点**:
- [ ] **无** "undefined symbol" 错误
- [ ] **无** "parsing ANY private key failed" 错误
- [ ] 日志显示 "SM2 load: encrypted PKCS#8 PEM decrypted successfully with password"

**实际输出**:
```
[待填写]
```

### 3.3 证书列表验证
```powershell
docker exec strongswan-gmsm swanctl --list-certs
```

**验证点**:
- [ ] 显示 CA 证书信息（subject: CN=SM2 Root CA）
- [ ] 显示服务器证书信息（subject: CN=vpn.example.com）
- [ ] 显示客户端证书信息（subject: CN=client@example.com）
- [ ] 证书公钥显示为 `ECDSA 256 bits` 或 `EC 256 bits`（SM2 曲线）

**实际输出**:
```
[待填写]
```

## 4. 日志分析

### 4.1 Charon 启动日志
```powershell
docker exec strongswan-gmsm grep -i "plugin.*gmsm\|SM2\|SM3\|SM4" /var/log/charon.log | head -n 20
```

**验证点**:
- [ ] "plugin 'gmsm': loaded successfully"
- [ ] "HASHER: HASH_SM3"
- [ ] "PRF: PRF_HMAC_SM3"
- [ ] "CRYPTER: ENCR_SM4_CBC"
- [ ] "AEAD: ENCR_SM4_GCM_ICV16"
- [ ] "KE: SM2_256"

### 4.2 证书解析日志
```powershell
docker exec strongswan-gmsm grep -E "SM2 load|SM2 curve detected|encrypted PKCS" /var/log/charon.log
```

**验证点**:
- [ ] "SM2 private loader entered"
- [ ] "SM2 load: encrypted PKCS#8 PEM decrypted successfully with password"
- [ ] **无** "all parsing attempts failed"

**实际输出**:
```
[待填写]
```

## 5. X.509 解析验证

### 5.1 证书详细信息
```powershell
docker exec strongswan-gmsm openssl x509 -in /etc/swanctl/x509/servercert.pem -text -noout | grep -A 5 "Public Key"
```

**验证点**:
- [ ] Public Key Algorithm 为 `id-ecPublicKey` 或包含 SM2 相关信息
- [ ] 曲线参数指向 SM2 OID (1.2.156.10197.1.301)

### 5.2 签名算法验证
```powershell
docker exec strongswan-gmsm openssl x509 -in /etc/swanctl/x509/servercert.pem -text -noout | grep "Signature Algorithm"
```

**预期**: 包含 SM2-with-SM3 或 1.2.156.10197.1.501

## 6. 代码集成验证

### 6.1 OID 常量生成
```bash
grep -E "OID_SM2P256V1|OID_SM3|OID_SM4|OID_SM2_WITH_SM3" src/libstrongswan/asn1/oid.h
```

**验证点**:
- [ ] `#define OID_SM2P256V1 ...`
- [ ] `#define OID_SM3 ...`
- [ ] `#define OID_SM4 ...`
- [ ] `#define OID_SM2_WITH_SM3 ...`

### 6.2 签名方案映射
```bash
grep -A 2 "case OID_SM2_WITH_SM3" src/libstrongswan/credentials/keys/public_key.c
```

**验证点**:
- [ ] `oid_to_signature_scheme` 中存在 `OID_SM2_WITH_SM3 → SIGN_SM2_WITH_SM3`
- [ ] `signature_scheme_to_oid` 中存在 `SIGN_SM2_WITH_SM3 → OID_SM2_WITH_SM3`
- [ ] `scheme_map[]` 包含 `{ KEY_SM2, 0, { .scheme = SIGN_SM2_WITH_SM3 }}`

### 6.3 加密私钥支持
```bash
grep "sm2_private_key_info_decrypt_from_pem" src/libstrongswan/plugins/gmsm/gmsm_sm2_private_key.c
```

**验证点**:
- [ ] 调用 `sm2_private_key_info_decrypt_from_pem` 与密码数组循环
- [ ] 回退逻辑：加密 → 未加密 → 传统格式

## 7. 功能测试

### 7.1 PSK + SM4-GCM 连接测试（baseline）
```powershell
# 配置使用 PSK 和 SM4-GCM-16
docker exec strongswan-gmsm swanctl --load-conns
docker exec strongswan-gmsm swanctl --initiate --child psk-sm4-gcm
```

**预期**: 连接成功，ESP SA 使用 SM4-GCM

### 7.2 SM2 证书认证连接测试（目标）
```powershell
# 配置使用 SM2 证书
docker exec strongswan-gmsm swanctl --initiate --child sm2-cert-test
```

**验证点**:
- [ ] IKE_SA_INIT 成功
- [ ] IKE_AUTH 使用 SM2 签名认证
- [ ] ESP SA 建立成功
- [ ] 数据包加密/解密正常

**实际输出**:
```
[待填写]
```

## 8. 性能测试（可选）

### 8.1 签名性能
```powershell
docker exec strongswan-gmsm bash -c "time for i in {1..100}; do /usr/local/bin/gmssl sm2sign -key /etc/swanctl/private/serverkey.pem -pass server1234 -in /etc/strongswan.conf -out /tmp/sig.bin 2>&1 | tail -1; done"
```

### 8.2 加密性能
```powershell
docker exec strongswan-gmsm bash -c "dd if=/dev/zero bs=1M count=10 | /usr/local/bin/gmssl sm4 -cbc -key 0123456789ABCDEF0123456789ABCDEF > /tmp/cipher.bin"
```

## 9. 问题记录

### 已解决
1. ✅ **OID_SM2_WITH_SM3 未定义**: 修改 oid.txt 层次结构
2. ✅ **OID_SM2_CURVE 不存在**: 使用 `OID_SM2P256V1`
3. ✅ **charon 进程崩溃**: 容器需要 `--privileged` 或 capabilities
4. ✅ **undefined symbol sm2_private_key_info_from_pem**: GmSSL 添加 `-DSM2_PRIVATE_KEY_EXPORT`
5. ✅ **加密私钥无法加载**: 实现 `sm2_private_key_info_decrypt_from_pem` 调用

### 待解决
[待填写]

## 10. 文件清单

### 修改的源代码文件
- [x] `Dockerfile.gmssl` - GmSSL cmake 添加 SM2_PRIVATE_KEY_EXPORT 宏
- [x] `src/libstrongswan/asn1/oid.txt` - 添加国密 OID 定义
- [x] `src/libstrongswan/plugins/x509/x509_cert.c` - SM2 曲线检测修复
- [x] `src/libstrongswan/credentials/keys/public_key.c` - SM2 签名方案映射
- [x] `src/libstrongswan/plugins/gmsm/gmsm_sm2_private_key.c` - 加密私钥解密支持

### 测试脚本
- [x] `test-sm2-integration.ps1` - 自动化集成测试（需修复中文编码）
- [x] `check-status.ps1` - 快速状态检查
- [x] `check-gmssl-symbols.ps1` - GmSSL 符号验证
- [x] `SM2-INTEGRATION-TESTING.md` - 详细测试文档

### 文档
- [x] `SM2-INTEGRATION-TESTING.md` - 集成测试报告
- [ ] `README.md` - 待更新容器权限说明

## 11. 下一步计划

- [ ] 完成当前构建（预计 10 分钟）
- [ ] 执行完整测试套件（本报告第 2-7 节）
- [ ] 修复发现的任何问题
- [ ] Git 提交所有代码变更
- [ ] 更新 README.md 文档
- [ ] 配置实际的 IKEv2 SM2 证书连接测试
- [ ] 性能基准测试
- [ ] 编写用户使用指南

---

**报告生成时间**: [待填写]  
**验证人员**: HankyZhang  
**strongSwan 版本**: 6.0.3dr1  
**GmSSL 版本**: 3.1.1
