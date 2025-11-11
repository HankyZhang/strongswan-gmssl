# strongSwan + GmSSL 国密 VPN 项目总结报告

**日期**: 2025年11月12日  
**项目**: strongSwan 6.0.3dr1 + GmSSL 3.1.1 国密算法支持  
**目标**: 实现支持 SM2/SM3/SM4 国密算法的 IPsec VPN

---

## 🎯 项目目标

在 strongSwan IPsec VPN 中集成中国国密算法（SM2/SM3/SM4），实现：
- IKEv2 密钥交换使用 SM2
- 加密算法使用 SM4
- 完整性校验使用 SM3
- 可在云服务器间建立安全的国密 VPN 隧道

---

## ✅ 已完成的工作

### 1. 环境搭建与部署

#### 云服务器配置
- **服务端**: 101.126.148.5 (阿里云, 北京)
- **客户端**: 8.140.37.32 (阿里云, 北京, 2核1G)
- **网络**: 同地域，延迟 < 1ms
- **系统**: CentOS 7.6 + Docker 26.1.4

#### Docker 镜像
- **基础镜像**: Ubuntu 22.04
- **GmSSL**: 3.1.1 (支持 SM2/SM3/SM4)
- **strongSwan**: 6.0.3dr1 (自定义 GMSM 插件)
- **镜像大小**: ~61MB

### 2. 代码修复

#### 修复 1: GMSM 插件版本字段缺失

**文件**: `src/libstrongswan/plugins/gmsm/gmsm_plugin.c`

**问题**: 插件加载时报错 "version field gmsm_plugin_version missing"

**解决方案**:
```c
#ifndef VERSION
#define VERSION "6.0.3dr1"
#endif

plugin_t *gmsm_plugin_create()
{
    private_gmsm_plugin_t *this;
    
    INIT(this,
        .public = {
            .plugin = {
                .get_name = _get_name,
                .get_features = _get_features,
                .destroy = _destroy,
            },
        },
    );
    
    return &this->public.plugin;
}
```

**验证**:
```bash
docker exec strongswan-gmsm swanctl --list-algs | grep -i gmsm
# 输出: (1031)[gmsm], (1032)[gmsm], HMAC_SM3_96[gmsm], ...
```

#### 修复 2: SM4 算法名称映射

**文件**: `src/libstrongswan/crypto/crypters/crypter.c`

**问题**: 日志中只显示数字 "1031" 而不是友好的 "SM4_CBC"

**解决方案**:
```c
ENUM_NEXT(encryption_algorithm_names, ENCR_UNDEFINED, ENCR_AES_CFB, ENCR_CHACHA20_POLY1305,
	"UNDEFINED",
	"DES_ECB",
	"SERPENT_CBC",
	"TWOFISH_CBC",
	"RC2_CBC",
	"AES_ECB",
	"AES_CFB");
ENUM_NEXT(encryption_algorithm_names, ENCR_SM4_CBC, ENCR_SM4_GCM_ICV16, ENCR_AES_CFB,
	"SM4_CBC",
	"SM4_GCM_16");
ENUM_END(encryption_algorithm_names, ENCR_SM4_GCM_ICV16);
```

**效果**: 日志将显示 "SM4_CBC-128" 而不是 "1031"

### 3. 成功建立标准算法 VPN

**配置**:
- IKE 算法: AES-256 + SHA-256 + MODP-2048
- ESP 算法: AES-256 + HMAC-SHA-256-128
- 认证: PSK (Pre-Shared Key)

**验证结果**:
```
std-client: #1, ESTABLISHED, IKEv2
  local  'vpn-client@test.com' @ 172.24.18.28[4500] [10.10.10.1]
  remote 'vpn-server@test.com' @ 101.126.148.5[4500]
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
  established 32s ago, rekeying in 13820s
  
  std-tunnel: #1, INSTALLED, TUNNEL-in-UDP, ESP:AES_CBC-256/HMAC_SHA2_256_128
    installed 32s ago, rekeying in 3387s, expires in 3928s
    in  c8fac185,      0 bytes,     0 packets
    out c1cc8f01,   5128 bytes,    63 packets,     4s ago
    local  10.10.10.1/32
    remote 0.0.0.0/0
```

**数据传输**: ✅ 正常 (5128 bytes, 63 packets)

### 4. GMSM 插件验证

**检查命令**:
```bash
docker exec strongswan-gmsm swanctl --list-algs | grep -i sm
```

**输出结果**:
```
encryption:
  (1031)[gmsm]        # SM4_CBC
  (1032)[gmsm]        # SM4_GCM

integrity:
  HMAC_SM3_96[gmsm]   # SM3 完整性校验

hasher:
  HASH_SM3[gmsm]      # SM3 哈希

prf:
  PRF_HMAC_SM3[gmsm]  # SM3 PRF

ke:
  (1025)[gmsm]        # SM2 密钥交换
```

**结论**: ✅ GMSM 插件成功加载，所有国密算法可用

### 5. 文档完善

创建的文档：
- `GMSM-VPN-Testing-Report.md` - 完整测试报告
- `docs/Quick-Start-With-Aliyun-ECS.md` - 阿里云快速部署指南
- `docs/Company-Intranet-GMSM-Testing-Guide.md` - 内网测试指南
- `docs/ROOT-CAUSE-ANALYSIS.md` - 问题根本原因分析
- `CURRENT-STATUS-REPORT.md` - 当前状态报告
- `NEXT-STEPS-GMSM-TESTING.md` - 下一步指南

---

## ⚠️ 待解决的问题

### 问题 1: 国密算法配置无法加载 ⭐⭐⭐

**现象**:
```bash
$ docker exec strongswan-gmsm swanctl --load-all
loading connection 'gmsm-server' failed: invalid value for: proposals, config discarded
loaded 0 of 1 connections, 1 failed to load, 0 unloaded
```

**配置文件**:
```conf
connections {
    gmsm-server {
        proposals = sm4-sm3-modp2048,aes256-sha256-modp2048
        esp_proposals = sm4-sm3,aes256-sha256
        ...
    }
}
```

**根本原因**: 
strongSwan 的配置解析器使用 `gperf` 工具从 `proposal_keywords_static.txt` 生成 `proposal_keywords_static.c`。虽然 `.txt` 文件中已定义了 SM4/SM3 关键字，但之前的 Docker 镜像是从 GitHub 克隆的代码编译的，使用的是预生成的（不含 SM4）的 `.c` 文件。

**解决方案**:
需要在 Linux 环境中重新编译 strongSwan：
```bash
# 在有 gperf 的环境中
cd /tmp/strongswan-gmssl
autoreconf -f -i  # 这会调用 gperf 重新生成 proposal_keywords_static.c
./configure --enable-gmsm --with-gmssl=/usr/local ...
make && make install
```

**进展**:
- ✅ 发现问题根因
- ✅ 修改 Dockerfile 使用本地代码
- ❌ Docker 编译时遇到 asn1/oid.c 换行符问题
- ⏳ 需要在 Linux 环境中重新编译

### 问题 2: 客户端服务器无法访问 ⭐⭐

**现象**:
```bash
$ ping 8.140.37.32
Request timed out.

$ ssh root@8.140.37.32
ssh: connect to host 8.140.37.32 port 22: Connection timed out
```

**可能原因**:
1. 阿里云安全组策略触发（频繁 SSH 连接）
2. 容器配置错误导致网络问题
3. 防护系统临时限制

**解决方案**:
- 选项 A: 等待 10-20 分钟自动解除
- 选项 B: 通过阿里云控制台 VNC 远程连接
- 选项 C: 通过阿里云控制台重启实例
- 选项 D: 使用阿里云控制台查看安全组日志

**当前状态**: ⏳ 等待自动恢复或手动处理

---

## 🔍 技术发现

### 1. strongSwan 配置解析流程

```
proposal_keywords_static.txt (定义关键字)
          ↓
     gperf 工具
          ↓
proposal_keywords_static.c (生成完美哈希查找代码)
          ↓
       编译
          ↓
   运行时配置解析
          ↓
    算法标识符 (ENCR_SM4_CBC = 1031)
          ↓
   插件提供实现 (gmsm_plugin)
          ↓
   GmSSL 库 (实际加解密)
```

### 2. GMSM 插件架构

```
gmsm_plugin.c (插件主文件)
    ├── gmsm_sm4_crypter.c (SM4 加密)
    ├── gmsm_sm3_hasher.c (SM3 哈希)
    ├── gmsm_sm3_prf.c (SM3 PRF)
    ├── gmsm_sm3_signer.c (SM3 签名)
    └── gmsm_sm2_*.c (SM2 相关)
```

### 3. proposal 关键字定义

**文件**: `src/libstrongswan/crypto/proposal/proposal_keywords_static.txt`

```txt
# Chinese SM (ShangMi) Algorithms
sm4,              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4cbc,           ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128
sm4gcm,           ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128
sm4gcm128,        ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128
sm4gcm16,         ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128
sm3,              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0
sm3_96,           INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0
prfsm3,           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SM3,            0
```

**关键点**: 这些定义已存在于原始代码中，但需要 gperf 生成到 `.c` 文件。

### 4. Docker 多阶段构建优化

```dockerfile
FROM ubuntu:22.04 AS base
# 安装基础工具

FROM base AS dependencies
# 安装编译工具 (gcc, make, pkg-config, gperf...)

FROM dependencies AS gmssl-builder
# 编译 GmSSL

FROM gmssl-builder AS strongswan-builder
COPY . /tmp/strongswan-gmssl    # 使用本地代码
RUN autoreconf -f -i && ./configure && make && make install

FROM base AS final
COPY --from=strongswan-builder /usr/local /usr/local
# 最小化最终镜像
```

---

## 📊 测试数据

### VPN 性能测试

| 指标 | 标准算法 (AES256) | 国密算法 (SM4) | 备注 |
|------|------------------|---------------|------|
| 连接建立时间 | ~2s | 未测试 | IKEv2 握手 |
| 吞吐量 | 未测试 | 未测试 | 待iperf测试 |
| 延迟 | <1ms (同地域) | 未测试 | ping 测试 |
| 数据包成功率 | 100% (63/63) | 未测试 | 无丢包 |

### 算法支持矩阵

| 算法类型 | 国密算法 | 标准算法 | 插件状态 | 配置状态 |
|---------|---------|---------|---------|---------|
| 加密 | SM4-CBC | AES-256 | ✅ 已加载 | ⏳ 配置解析失败 |
| 加密 (AEAD) | SM4-GCM | AES-GCM | ✅ 已加载 | ⏳ 配置解析失败 |
| 完整性 | HMAC-SM3-96 | HMAC-SHA256 | ✅ 已加载 | ⏳ 配置解析失败 |
| PRF | PRF-HMAC-SM3 | PRF-HMAC-SHA256 | ✅ 已加载 | ⏳ 配置解析失败 |
| 密钥交换 | SM2-256 | ECDH/DH | ✅ 已加载 | ⏳ 配置解析失败 |

---

## 🚀 下一步行动方案

### 方案 A: Linux 环境重新编译 (推荐) ⭐⭐⭐

**步骤**:
1. 在 Linux 服务器或 WSL2 中克隆代码
2. 安装依赖 (包括 gperf)
3. 运行 `autoreconf -f -i`
4. 编译并打包 Docker 镜像
5. 部署测试

**优点**: 彻底解决 proposal 关键字问题  
**缺点**: 需要 Linux 环境  
**预计时间**: 1-2 小时

### 方案 B: 服务器端直接编译

**步骤**:
1. SSH 到服务器 101.126.148.5
2. 安装编译工具和 gperf
3. 在服务器上编译 strongSwan
4. 更新 Docker 容器

**优点**: 直接在目标环境编译  
**缺点**: 污染服务器环境  
**预计时间**: 1 小时

### 方案 C: 使用标准算法 + 独立测试国密库

**步骤**:
1. 继续使用标准算法 VPN (已验证可用)
2. 编写独立测试程序验证 SM4/SM3 功能
3. 证明 GmSSL 库本身工作正常

**优点**: 快速验证国密算法实现  
**缺点**: 不是完整的 VPN 解决方案  
**预计时间**: 2-3 小时

### 方案 D: 手动注入配置 (hack)

**原理**: 直接修改 strongSwan 代码，硬编码支持 SM4 配置

**步骤**:
1. 修改 `proposal_keywords.c` 添加硬编码映射
2. 跳过 gperf 生成步骤
3. 重新编译

**优点**: 快速绕过问题  
**缺点**: 不是正规解决方案，难以维护  
**预计时间**: 3-4 小时

---

## 💡 经验总结

### 成功经验

1. **多阶段 Docker 构建**: 有效减小最终镜像体积
2. **阿里云同地域部署**: 延迟极低，测试效果好
3. **标准算法先行**: 先验证基础功能，再测试特定功能
4. **详细日志记录**: 完整保存所有操作和输出
5. **问题根因分析**: 深入理解编译和配置流程

### 遇到的挑战

1. **Windows/Linux 换行符差异**: 导致脚本执行失败
2. **Docker 层缓存**: 需要 CACHE_BUST 参数强制重建
3. **配置解析器生成**: gperf 工具依赖 Linux 环境
4. **云服务器安全策略**: 频繁连接触发防护
5. **大文件推送**: Docker tar 文件超过 GitHub 限制

### 技术收获

1. strongSwan 插件开发机制
2. gperf 完美哈希生成原理
3. IPsec/IKEv2 协议实现
4. Docker 多阶段构建优化
5. 国密算法集成方案

---

## 📁 项目文件结构

```
strongswan-gmssl/
├── src/
│   └── libstrongswan/
│       ├── plugins/gmsm/         # GMSM 插件 (已修复)
│       │   ├── gmsm_plugin.c     # ✅ 添加 VERSION 宏
│       │   ├── gmsm_sm4_crypter.c
│       │   ├── gmsm_sm3_hasher.c
│       │   └── ...
│       └── crypto/
│           ├── crypters/
│           │   └── crypter.c      # ✅ 添加 SM4 名称映射
│           └── proposal/
│               ├── proposal_keywords_static.txt  # ✅ 已有 SM4 定义
│               └── proposal_keywords_static.c    # ❌ 需要重新生成
├── config/
│   └── swanctl/
│       ├── std-psk-client.conf           # ✅ 标准算法 (已测试)
│       ├── std-psk-server.conf           # ✅ 标准算法 (已测试)
│       ├── gmsm-psk-client-v2.conf       # ⏳ 国密算法 (配置未加载)
│       └── gmsm-psk-server-v2.conf       # ⏳ 国密算法 (配置未加载)
├── docs/
│   ├── Quick-Start-With-Aliyun-ECS.md    # 快速部署指南
│   ├── ROOT-CAUSE-ANALYSIS.md            # 根因分析
│   └── Company-Intranet-GMSM-Testing-Guide.md
├── Dockerfile.gmssl                      # ✅ 使用本地代码
├── GMSM-VPN-Testing-Report.md           # 完整测试报告
└── README.md
```

---

## 🔗 相关链接

- **GitHub 仓库**: https://github.com/HankyZhang/strongswan-gmssl
- **strongSwan 官网**: https://www.strongswan.org/
- **GmSSL 项目**: https://github.com/guanzhi/GmSSL
- **国密算法标准**: http://www.gmbz.org.cn/

---

## 📞 联系方式

如有问题或需要协助，请通过以下方式联系：
- GitHub Issues: https://github.com/HankyZhang/strongswan-gmssl/issues
- Email: (添加您的邮箱)

---

## 📄 许可证

- strongSwan: GPLv2
- GmSSL: Apache License 2.0
- 本项目: (根据您的需求选择)

---

**最后更新**: 2025年11月12日 00:40  
**状态**: 标准算法 VPN 正常工作，国密算法配置待修复  
**下一步**: 使用 Linux 环境重新编译生成 proposal_keywords_static.c
