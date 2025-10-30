# strongSwan SM 算法提案支持 - 实现方案

**日期**: 2025-10-30  
**问题**: strongSwan 无法在配置文件中使用 SM4/SM3 算法  
**状态**: 需要源码级修改

---

## 问题分析

### 1. 当前状态

✅ **已完成**:
- gmsm 插件编译成功
- SM2/SM3/SM4 算法已注册到 strongSwan
- `swanctl --list-algs` 显示算法可用
  - `(1031)[gmsm]` - SM4-CBC
  - `(1032)[gmsm]` - SM4-GCM
  - `HASH_SHA3_512[gmsm]` - SM3

❌ **问题**:
- 配置文件无法使用 SM 算法关键字
- 尝试 `proposals = sm4-sm3-modp2048` → 加载失败
- 尝试 `proposals = 1031-sha256-modp2048` → 加载失败
- 错误: `invalid value for: proposals`

### 2. 根本原因

strongSwan 的提案解析器使用**预定义关键字**来映射算法，定义在:
```
src/libstrongswan/crypto/proposal/proposal_keywords_static.txt
```

该文件包含所有支持的算法关键字，例如:
```c
aes256,           ENCRYPTION_ALGORITHM, ENCR_AES_CBC,            256
sha256,           INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_256_128,    0
modp2048,         KEY_EXCHANGE_METHOD, MODP_2048_BIT,              0
```

**SM 算法未定义在此文件中**，因此配置解析失败。

---

## 解决方案

### 方案 A: 添加 SM 算法关键字 (推荐)

#### A.1 修改源文件

**文件**: `src/libstrongswan/crypto/proposal/proposal_keywords_static.txt`

在适当位置添加:

```c
# 在 ENCRYPTION_ALGORITHM 部分（twofish256 之后）
sm4,              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4cbc,           ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4gcm,           ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128
sm4gcm16,         ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128

# 在 INTEGRITY_ALGORITHM 部分（aescmac 之后）
sm3,              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0

# 在 PSEUDO_RANDOM_FUNCTION 部分（prfaescmac 之后）
prfsm3,           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SM3,            0
```

#### A.2 定义缺失的常量

**问题**: `AUTH_HMAC_SM3_96` 和 `PRF_HMAC_SM3` 尚未定义

**解决**:

1. **编辑** `src/libstrongswan/crypto/signers/signer.h`:
   ```c
   enum integrity_algorithm_t {
       // ... 现有定义 ...
       AUTH_CAMELLIA_XCBC_96 = 1030,
       /** SM3 HMAC 96 bit */
       AUTH_HMAC_SM3_96 = 1034,  // ← 添加这行
   };
   ```

2. **编辑** `src/libstrongswan/crypto/prfs/prf.h`:
   ```c
   enum pseudo_random_function_t {
       // ... 现有定义 ...
       PRF_CAMELLIA128_XCBC = 1030,
       /** HMAC-SM3 PRF */
       PRF_HMAC_SM3 = 1034,  // ← 添加这行
   };
   ```

3. **编辑相应的 .c 文件**添加名称映射（signer.c, prf.c）

#### A.3 实现 HMAC-SM3 签名器和 PRF

**挑战**: gmsm 插件目前只提供哈希器，不提供签名器或 PRF。

**方案1** (简单): 基于 SM3 哈希实现通用 HMAC
- 创建 `gmsm_sm3_signer.c` - HMAC-SM3 签名器
- 创建 `gmsm_sm3_prf.c` - SM3 PRF
- 在 `gmsm_plugin.c` 中注册

**方案2** (权宜): 先用 SHA256 代替
- 配置: `proposals = sm4-sha256-modp2048`
- 仅 SM4 加密，认证使用 SHA256
- **当前最快可行方案**

#### A.4 重新编译

```bash
cd /tmp/strongswan-gmsm
./autogen.sh
./configure --prefix=/usr --sysconfdir=/etc \
    --enable-gmsm --enable-openssl --enable-swanctl \
    --enable-vici --disable-gmp
make -j$(nproc)
sudo make install
```

---

### 方案 B: 使用现有算法 (临时方案)

**原理**: 仅将 SM4 用于加密，完整性使用标准算法

#### B.1 配置示例

```conf
connections {
    gmsm-hybrid {
        proposals = sm4-sha256-modp2048
        # SM4 加密 (需要关键字支持)
        # SHA256 HMAC
        # Modp2048 DH
        
        children {
            tunnel {
                esp_proposals = sm4-sha256
            }
        }
    }
}
```

**问题**: 仍然需要添加 `sm4` 关键字

---

### 方案 C: PSK 认证 + AES 算法 (当前可行)

**原理**: 先验证 PSK 认证和 VPN 功能，暂不使用 SM 算法

#### C.1 当前配置

```conf
connections {
    gmsm-psk {
        proposals = aes256-sha256-modp2048  # 标准算法
        
        local {
            auth = psk
            id = vpn-client@test.local
        }
        
        remote {
            auth = psk
            id = vpn-server@test.local
        }
        
        children {
            gmsm-tunnel {
                esp_proposals = aes256-sha256
                local_ts = 10.0.0.1/32
                remote_ts = 10.0.0.2/32
            }
        }
    }
}

secrets {
    ike-1 {
        id-client = vpn-client@test.local
        id-server = vpn-server@test.local
        secret = "GmSM_Test_PSK_2024"
    }
}
```

**优点**:
- ✅ 无需修改源码
- ✅ 可立即测试 VPN 连接
- ✅ 验证 PSK 认证流程

**缺点**:
- ❌ 未使用 SM 算法

---

## 推荐实施路径

### 阶段 1: 验证基础功能 (立即执行)

1. **配置**: 使用方案 C (PSK + AES)
2. **测试 VPN 连接**:
   ```bash
   sudo swanctl --load-all
   sudo swanctl --initiate --child gmsm-tunnel
   sudo swanctl --list-sas
   ```
3. **验证**: IKE SA 和 Child SA 建立成功

### 阶段 2: 添加 SM 算法关键字 (短期)

1. **修改源文件**:
   - `proposal_keywords_static.txt` - 添加 sm4/sm3 关键字
   - `signer.h` - 定义 AUTH_HMAC_SM3_96
   - `prf.h` - 定义 PRF_HMAC_SM3

2. **实现 HMAC-SM3**:
   - 创建 `gmsm_sm3_signer.c`
   - 创建 `gmsm_sm3_prf.c`
   - 更新 `gmsm_plugin.c`

3. **重新编译和安装**

### 阶段 3: 完整 SM 算法支持 (中期)

1. **配置**: `proposals = sm4-sm3-modp2048`
2. **测试**: 端到端 SM 算法 VPN
3. **性能测试**: 与 AES/SHA2 对比

---

## 当前状态总结

### ✅ 可用功能
- strongSwan 5.9.6 运行
- gmsm 插件加载
- SM2/SM3/SM4 算法注册
- PSK 认证配置

### ⏸️ 受限功能
- SM 算法提案 (需要关键字)
- SM2 证书认证 (需要 X.509 解析器)

### 📋 待实现
- SM 算法关键字定义
- HMAC-SM3 签名器
- SM3 PRF
- 端到端 SM VPN 测试

---

## 下一步行动

### 立即 (今天)

1. ✅ **测试 PSK + AES VPN 连接**
   - 验证基础 VPN 功能
   - 确认配置流程正确

2. 🔄 **准备源码修改**
   - 创建 `gmsm_sm3_signer.c` 模板
   - 创建 `gmsm_sm3_prf.c` 模板
   - 更新 proposal_keywords_static.txt

### 短期 (本周)

3. **重新编译 strongSwan**
   - 应用 SM 算法关键字补丁
   - 重新安装

4. **测试 SM 算法 VPN**
   - `proposals = sm4-sm3-modp2048`
   - 验证实际使用 SM 算法

---

## 参考资料

### 关键文件位置

```
src/libstrongswan/crypto/proposal/
  ├── proposal_keywords_static.txt   ← 算法关键字定义
  ├── proposal_keywords.c            ← 关键字解析器
  
src/libstrongswan/crypto/
  ├── crypters/crypter.h             ← ENCR_SM4_CBC (1031)
  ├── signers/signer.h               ← AUTH_HMAC_SM3 (需添加)
  ├── prfs/prf.h                     ← PRF_HMAC_SM3 (需添加)
  ├── hashers/hasher.h               ← HASH_SM3 (1033)
  
src/libstrongswan/plugins/gmsm/
  ├── gmsm_plugin.c                  ← 插件注册
  ├── gmsm_sm3_hasher.c              ← SM3 哈希 (已实现)
  ├── gmsm_sm3_signer.c              ← HMAC-SM3 (待创建)
  ├── gmsm_sm3_prf.c                 ← SM3 PRF (待创建)
```

### 编译命令

```bash
# 清理
cd /tmp/strongswan-gmsm/strongswan-5.9.6
make clean

# 配置
./configure --prefix=/usr --sysconfdir=/etc \
    --enable-gmsm --enable-openssl --enable-swanctl \
    --enable-vici --disable-gmp \
    --with-systemdsystemunitdir=no

# 编译
make -j$(nproc)

# 安装
sudo make install
sudo systemctl restart strongswan-starter
```

---

**结论**: SM 算法关键字支持需要源码级修改，建议先验证基础 VPN 功能（PSK + AES），再实施完整 SM 算法支持。
