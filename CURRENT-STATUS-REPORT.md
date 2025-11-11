# 国密 VPN 测试 - 当前状态报告

**时间**: 2025年11月12日 00:10
**状态**: 客户端服务器暂时无法访问，服务器端镜像上传中

---

## 📊 当前进度

### ✅ 已完成的工作

1. **发现并修复核心问题**
   - ✅ GMSM 插件版本字段缺失 → 已修复
   - ✅ SM4 算法名称未注册到枚举表 → 已添加到 `crypter.c`
   - ✅ 发现配置关键字：`sm4`, `sm3`, `prfsm3`

2. **成功建立标准算法 VPN**
   - ✅ 客户端: 8.140.37.32
   - ✅ 服务端: 101.126.148.5
   - ✅ 算法: AES-256 + SHA-256
   - ✅ 数据传输: 正常 (5128 bytes, 63 packets)

3. **编译新版本镜像**
   - ✅ strongswan-gmssl:3.1.1-gmsm-v2
   - ✅ 包含 SM4 算法名称映射
   - ✅ 镜像大小: 61MB

4. **部署到客户端**
   - ✅ 镜像已上传到 8.140.37.32
   - ✅ 容器已更新并运行

---

## ⚠️ 当前问题

### 问题1: 客户端服务器无法访问

**现象:**
```
ping 8.140.37.32
Request timed out.

ssh root@8.140.37.32
ssh: connect to host 8.140.37.32 port 22: Connection timed out
```

**可能原因:**
1. 阿里云安全组策略触发（频繁 SSH 连接）
2. 容器配置错误导致系统问题
3. 网络暂时性故障

**解决方案:**
- 等待 5-10 分钟让阿里云自动解除限制
- 或通过阿里云控制台重启实例
- 或使用阿里云控制台的 VNC 远程连接

### 问题2: 配置关键字不被识别

**现象:**
```
loading connection 'gmsm-client' failed: invalid value for: proposals, config discarded
```

**尝试的配置:**
- ❌ `proposals = 1031-sm3-modp2048` (数字形式)
- ❌ `proposals = sm4-sm3-modp2048` (关键字形式)

**分析:**
虽然 `proposal_keywords_static.txt` 中定义了关键字，但配置解析器仍然无法识别。这可能是因为：
1. strongSwan 的配置解析是编译时生成的
2. 需要重新生成 proposal 解析器
3. 可能有其他配置文件需要更新

---

## 🔍 技术发现

### 1. strongSwan 算法注册机制

**插件注册** (`gmsm_plugin.c`):
```c
PLUGIN_REGISTER(CRYPTER, gmsm_sm4_crypter_create),
    PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_CBC, 16),
    PLUGIN_PROVIDE(CRYPTER, ENCR_SM4_GCM_ICV16, 16),
```

**算法枚举** (`crypter.h`):
```c
ENCR_SM4_CBC = 1031,
ENCR_SM4_GCM_ICV16 = 1032,
```

**算法名称映射** (`crypter.c`) - **已修复**:
```c
ENUM_NEXT(encryption_algorithm_names, ENCR_SM4_CBC, ENCR_SM4_GCM_ICV16, ENCR_AES_CFB,
    "SM4_CBC",
    "SM4_GCM_16");
ENUM_END(encryption_algorithm_names, ENCR_SM4_GCM_ICV16);
```

**配置关键字** (`proposal_keywords_static.txt`):
```
sm4,              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4cbc,           ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4gcm,           ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128
sm3,              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0
prfsm3,           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SM3,            0
```

### 2. 配置解析流程

strongSwan 的配置解析可能有两个步骤：
1. **编译时**: 从 `proposal_keywords_static.txt` 生成解析器代码
2. **运行时**: 使用生成的代码解析配置文件

**关键文件:**
- `src/libstrongswan/crypto/proposal/proposal_keywords.h` (生成的)
- `src/libstrongswan/crypto/proposal/proposal_keywords.c` (生成的)

### 3. 可能需要的额外步骤

检查是否有生成脚本：
```bash
find src -name "*.py" -o -name "*.pl" -o -name "*generate*" | grep proposal
```

或者检查 Makefile 中的 proposal 相关目标。

---

## 📋 下一步计划

### 短期任务（今天）

1. **等待客户端恢复访问** (5-10分钟)
   - 定期 ping 测试
   - 或使用阿里云控制台 VNC

2. **完成服务器端镜像上传**
   - 当前进度: 上传中（后台运行）
   - 预计时间: 25分钟

3. **研究 proposal 关键字解析**
   - 查找生成脚本
   - 检查是否需要重新生成解析器
   - 或使用其他方式指定算法

### 中期任务（明天）

4. **尝试替代方案**
   - 方案 A: 使用 ipsec.conf 而不是 swanctl.conf
   - 方案 B: 直接修改代码支持数字标识符
   - 方案 C: 研究 strongSwan 的算法协商日志

5. **如果配置问题无法解决**
   - 使用标准算法建立 VPN (已验证可行)
   - 手动测试 SM4 加密库 (GmSSL)
   - 编写测试程序验证 SM4/SM3 功能

---

## 💡 替代测试方案

如果配置方式无法工作，可以考虑：

### 方案 A: 编程方式测试

创建独立的测试程序：
```c
#include <gmssl/sm4.h>
#include <gmssl/sm3.h>

int main() {
    // 测试 SM4 加密
    SM4_KEY key;
    sm4_set_encrypt_key(&key, test_key);
    sm4_encrypt(&key, plaintext, ciphertext);
    
    // 测试 SM3 哈希
    SM3_CTX ctx;
    sm3_init(&ctx);
    sm3_update(&ctx, data, len);
    sm3_final(&ctx, hash);
    
    return 0;
}
```

### 方案 B: 使用 ipsec.conf

老式配置可能支持不同的算法指定方式：
```
conn gmsm-test
    keyexchange=ikev2
    ike=sm4-sm3-modp2048!
    esp=sm4-sm3!
    ...
```

### 方案 C: 修改代码直接映射

在配置解析器中添加硬编码映射：
```c
if (strcmp(token, "sm4") == 0) {
    return ENCR_SM4_CBC;
}
```

---

## 📞 需要帮助的问题

1. **客户端服务器无法访问**
   - 是否需要通过阿里云控制台操作？
   - 是否要等待自动恢复？

2. **配置关键字不识别**
   - 是否有 proposal 生成脚本？
   - 是否需要重新编译 strongSwan？

3. **测试方向选择**
   - 继续解决配置问题？
   - 还是先用标准算法完成 VPN 功能测试？

---

## 📂 相关文件

- `src/libstrongswan/crypto/crypters/crypter.c` - ✅ 已修改
- `src/libstrongswan/crypto/crypters/crypter.h` - ✅ 算法定义完整
- `src/libstrongswan/crypto/proposal/proposal_keywords_static.txt` - ✅ 关键字已定义
- `src/libstrongswan/plugins/gmsm/gmsm_plugin.c` - ✅ 插件已修复
- `config/swanctl/gmsm-psk-client-v2.conf` - ⚠️ 配置无法加载
- `config/swanctl/gmsm-psk-server-v2.conf` - ⚠️ 配置无法加载

---

## 🎯 成功标准

**最终目标**: 在两台云服务器之间建立使用国密算法的 VPN 连接

**验证方法**:
```bash
swanctl --list-sas
```

**预期输出**:
```
gmsm-client: #1, ESTABLISHED, IKEv2
  SM4_CBC-128/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
  
  gmsm-tunnel: #1, INSTALLED, TUNNEL
    ESP:SM4_CBC-128/HMAC_SM3_96
```

**退而求其次**: 标准算法 VPN (已实现) + 独立的 SM4/SM3 功能测试

---

**建议**: 现在先休息，等客户端服务器恢复后再继续测试。
