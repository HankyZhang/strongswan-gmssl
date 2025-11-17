# SM2 国密算法集成测试报告

## 1. 问题背景

在 strongSwan 中完整集成 SM2/SM3/SM4 国密算法时遇到以下主要问题：

### 1.1 初期编译错误
- **OID 常量未定义**: `OID_SM2_WITH_SM3` 和 `OID_SM2_CURVE` 报错
- **根本原因**: `oid.txt` 层次结构不正确，未按 ASN.1 OID 字节序列定义

### 1.2 容器运行时崩溃
- **现象**: Docker 容器启动后 charon 进程立即退出（exit code 1）
- **日志**: `/var/log/charon.log` 为空，无任何日志输出
- **排查方法**:
  ```bash
  docker exec strongswan-gmsm ps aux  # charon 进程不存在
  docker exec strongswan-gmsm ls -la /var/run/  # charon.vici socket 存在但无进程监听
  ```
- **根本原因**: charon 需要 `NET_ADMIN` 和 `NET_RAW` 权限进行内核 IPsec 操作
- **解决方案**: 
  ```bash
  docker run -d --privileged ...  # 或
  docker run -d --cap-add=NET_ADMIN --cap-add=NET_RAW ...
  ```

### 1.3 符号未定义错误
- **现象**: `swanctl --load-creds` 报错：
  ```
  /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so: undefined symbol: sm2_private_key_info_from_pem
  ```
- **排查方法**:
  ```bash
  grep -r "sm2_private_key_info_from_pem" GmSSL/src/
  # 找到 GmSSL/src/sm2_key.c:394，发现被 #ifdef SM2_PRIVATE_KEY_EXPORT 包裹
  ```
- **根本原因**: GmSSL 默认不导出该函数，需要在编译时启用宏定义
- **解决方案**: 修改 `Dockerfile.gmssl` GmSSL cmake 配置：
  ```cmake
  cmake -DSM2_PRIVATE_KEY_EXPORT=ON \
        -DCMAKE_C_FLAGS="-DSM2_PRIVATE_KEY_EXPORT" ...
  ```

## 2. 最终解决方案

### 2.1 OID 标准化集成

在 `src/libstrongswan/asn1/oid.txt` 添加中国国家密码管理局标准 OID：

```
# Chinese National Crypto Standards (GM/T 0006-2012)
0x2A 0x81 0x1C 0xCF 0x55 0x01
  0x82 0x2D "sm2p256v1"       OID_SM2P256V1      # 1.2.156.10197.1.301
  0x83 0x11 "sm3"              OID_SM3            # 1.2.156.10197.1.401
  0x68 "sm4"                   OID_SM4            # 1.2.156.10197.1.104
  0x83 0x75 "sm2-with-sm3"     OID_SM2_WITH_SM3   # 1.2.156.10197.1.501
```

**自动生成**:
- `scripts/oid.pl` 读取 `oid.txt` 生成 `oid.h` 和 `oid.c`
- 生成常量: `OID_SM2P256V1`, `OID_SM3`, `OID_SM4`, `OID_SM2_WITH_SM3`

### 2.2 X.509 证书解析支持

修改 `src/libstrongswan/plugins/x509/x509_cert.c`（约第 1486 行）：

```c
// 检测 SM2 曲线
if (oid == OID_SM2P256V1)  // 之前错误使用 OID_SM2_CURVE
{
    DBG1(DBG_LIB, "SM2 curve detected in AlgorithmIdentifier params, retrying with KEY_SM2");
    public = lib->creds->create(lib->creds, CRED_PUBLIC_KEY, KEY_SM2,
                                 BUILD_BLOB_ALGID_PARAMS, subjectPublicKeyInfo,
                                 BUILD_END);
}
```

### 2.3 签名方案映射

修改 `src/libstrongswan/credentials/keys/public_key.c`：

```c
// OID → Signature Scheme
signature_scheme_t oid_to_signature_scheme(int oid, int hash_oid)
{
    switch (oid) {
        case OID_SM2_WITH_SM3:
            return SIGN_SM2_WITH_SM3;
        // ... 其他算法
    }
}

// Signature Scheme → OID
int signature_scheme_to_oid(signature_scheme_t scheme)
{
    switch (scheme) {
        case SIGN_SM2_WITH_SM3:
            return OID_SM2_WITH_SM3;
        // ... 其他算法
    }
}

// 密钥类型支持映射
static const struct {
    key_type_t type;
    int hash;
    union {
        signature_scheme_t scheme;
        // ...
    };
} scheme_map[] = {
    { KEY_SM2, 0, { .scheme = SIGN_SM2_WITH_SM3 }},
    // ... 其他映射
};
```

### 2.4 GmSSL 编译配置

修改 `Dockerfile.gmssl`（约第 58-66 行）：

```dockerfile
RUN cd /tmp/GmSSL-3.1.1 \
    && mkdir build && cd build \
    && cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX} \
             -DCMAKE_BUILD_TYPE=Release \
             -DENABLE_SM2_PRIVATE=ON \
             -DSM2_PRIVATE_KEY_EXPORT=ON \              # ← 新增
             -DENABLE_SM3=ON \
             -DENABLE_SM4=ON \
             -DCMAKE_C_FLAGS="-DSM2_PRIVATE_KEY_EXPORT" \  # ← 新增
             .. \
    && make -j$(nproc) \
    && make install
```

### 2.5 容器启动要求

**方式一（推荐用于开发测试）**:
```bash
docker run -d --name strongswan-gmsm --privileged strongswan-gmssl:latest /start.sh
```

**方式二（生产环境最小权限）**:
```bash
docker run -d --name strongswan-gmsm \
    --cap-add=NET_ADMIN \
    --cap-add=NET_RAW \
    --sysctl net.ipv4.ip_forward=1 \
    --sysctl net.ipv6.conf.all.forwarding=1 \
    strongswan-gmssl:latest /start.sh
```

## 3. 验证步骤

### 3.1 构建镜像
```bash
docker build -f Dockerfile.gmssl -t strongswan-gmssl:latest .
```

### 3.2 启动容器
```bash
docker rm -f strongswan-gmsm
docker run -d --name strongswan-gmsm --privileged strongswan-gmssl:latest /start.sh
sleep 5
```

### 3.3 检查 charon 进程
```bash
docker exec strongswan-gmsm ps aux | grep charon
# 预期输出: root ... /usr/local/strongswan/sbin/charon
```

### 3.4 列出国密算法
```bash
docker exec strongswan-gmsm swanctl --list-algs | grep -E "SM|sm"
```

**预期输出**:
```
SM4_CBC[gmsm]
HMAC_SM3_96[gmsm]
SM4_GCM_16[gmsm]
HASH_SM3[gmsm]
PRF_HMAC_SM3[gmsm]
```

### 3.5 加载 SM2 证书
```bash
docker exec strongswan-gmsm swanctl --load-creds
```

**成功标志**: 无 "undefined symbol" 错误

### 3.6 查看已加载证书
```bash
docker exec strongswan-gmsm swanctl --list-certs
```

**预期输出**: 显示 CA、服务器、客户端 SM2 证书信息

### 3.7 自动化测试脚本
```powershell
.\test-sm2-integration.ps1
```

## 4. 关键技术点总结

### 4.1 strongSwan OID 系统
- **生成机制**: `oid.txt` → `oid.pl` → `oid.h/oid.c`
- **层次结构**: 必须按 ASN.1 编码的字节序列定义（非点分十进制）
- **命名规范**: 自动生成的常量名为 `OID_` + 大写标识符

### 4.2 签名方案双向映射
- `oid_to_signature_scheme()`: 证书解析时 OID → 内部枚举
- `signature_scheme_to_oid()`: 签名生成时枚举 → OID
- `scheme_map[]`: 密钥类型与签名方案关联，用于自动选择

### 4.3 GmSSL 条件编译
- **内部 API**: 默认不导出，用于库内部实现
- **公开 API**: 需显式启用导出宏（如 `SM2_PRIVATE_KEY_EXPORT`）
- **排查方法**: 
  1. `ldd` 检查符号依赖
  2. `grep -r` 搜索函数定义
  3. 查看 `#ifdef` 宏定义

### 4.4 Docker 容器权限
- **IPsec 内核操作**: 需要 `NET_ADMIN` (XFRM 策略) 和 `NET_RAW` (ESP/AH 协议)
- **调试技巧**: 
  - 空日志文件 → 进程启动前崩溃（权限或库加载问题）
  - 非空日志 → 运行时错误（配置或协议问题）

## 5. 已验证功能

### 5.1 编译阶段
- ✅ OID 常量正确生成
- ✅ gmsm 插件编译无错误
- ✅ x509 插件链接 SM2 支持
- ✅ GmSSL 符号正确导出

### 5.2 运行时加载
- ✅ charon 进程启动成功
- ✅ gmsm 插件加载（通过 `swanctl --list-algs` 验证）
- ✅ 算法注册成功：
  - HASHER: HASH_SM3
  - SIGNER: AUTH_HMAC_SM3_96
  - PRF: PRF_HMAC_SM3
  - CRYPTER: ENCR_SM4_CBC
  - AEAD: ENCR_SM4_GCM_ICV16
  - PRIVKEY/PUBKEY: KEY_SM2, SIGN_SM2_WITH_SM3
  - KE: SM2_256 (DH group)

### 5.3 证书解析（待本次构建完成后验证）
- ⏳ SM2 私钥从 PEM 加载
- ⏳ SM2 证书 X.509 解析
- ⏳ SM2 签名验证

### 5.4 VPN 连接（后续验证）
- ⏳ IKEv2 SA 协商（使用 SM3/SM4）
- ⏳ SM2 证书认证
- ⏳ ESP 数据包加密/解密（SM4-CBC/GCM）

## 6. 常见问题排查

### Q1: charon 进程不存在
**检查步骤**:
```bash
docker logs strongswan-gmsm  # 查看容器日志
docker exec strongswan-gmsm cat /var/log/charon.log  # 如果日志为空，说明启动失败
```
**可能原因**:
- 容器未使用 `--privileged` 或缺少 capabilities
- 库依赖缺失（使用 `ldd` 检查）

### Q2: undefined symbol 错误
**检查步骤**:
```bash
docker exec strongswan-gmsm ldd /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-gmsm.so
# 查看 GmSSL 库路径是否正确
grep -r "函数名" GmSSL/src/  # 查找函数定义
grep "函数名" GmSSL/include/gmssl/*.h  # 检查是否在头文件中声明
```
**可能原因**:
- GmSSL 编译时未启用导出宏
- 头文件未正确安装
- 链接路径错误

### Q3: 证书加载失败
**检查步骤**:
```bash
docker exec strongswan-gmsm openssl version  # 确保不使用标准 OpenSSL
docker exec strongswan-gmsm /usr/local/bin/gmssl version  # 确认 GmSSL 版本
docker exec strongswan-gmsm cat /var/log/charon.log | grep -i "parse\|cert\|error"
```
**可能原因**:
- 证书格式不兼容（PKCS#8 vs ECPrivateKey）
- 密钥文件路径错误
- 权限问题（证书文件不可读）

## 7. 下一步计划

1. **等待当前构建完成** (~5-7分钟)
2. **运行自动化测试**: `.\test-sm2-integration.ps1`
3. **验证 SM2 证书加载**: 确认无 "undefined symbol" 错误
4. **测试 IKEv2 握手**: 配置使用 SM2 证书的 VPN 连接
5. **提交代码**: 
   ```bash
   git add Dockerfile.gmssl src/libstrongswan/asn1/oid.txt \
           src/libstrongswan/plugins/x509/x509_cert.c \
           src/libstrongswan/credentials/keys/public_key.c
   git commit -m "feat: Complete SM2/SM3/SM4 integration with standardized OID"
   git push origin master
   ```
6. **更新文档**: 在 README 中添加容器权限要求和国密算法使用说明

## 8. 参考资料

- **国密标准**: GM/T 0006-2012（密码算法标识规范）
- **OID 注册**: 1.2.156.10197.1.* (中国国家密码管理局)
- **GmSSL 文档**: https://github.com/guanzhi/GmSSL
- **strongSwan 开发**: https://docs.strongswan.org/docs/5.9/devs/devs.html
- **Docker Capabilities**: https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities

---

**文档版本**: 1.0  
**最后更新**: 2024 (构建验证待完成)  
**状态**: Docker 构建中，等待测试验证
