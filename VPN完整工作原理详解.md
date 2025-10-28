# VPN（虚拟私有网络）完整工作原理详解

## 一、VPN的核心概念

VPN就像在公共互联网上建立一条"加密隧道"，让两个远程网络或设备能够安全地通信，就像它们在同一个私有网络中一样。

```
公网传输示意图：
┌────────────┐                                        ┌────────────┐
│  企业网络A  │                                        │  企业网络B  │
│ 10.1.0.0/16│                                        │ 10.2.0.0/16│
└─────┬──────┘                                        └──────┬─────┘
      │                                                      │
┌─────▼──────┐      加密隧道                         ┌──────▼─────┐
│  网关Moon  │══════════════════════════════════════►│  网关Sun   │
│192.168.0.1 │     通过不安全的Internet传输           │192.168.0.2 │
└────────────┘     但数据已加密保护                   └────────────┘
      ▲                                                      ▲
      │ 明文数据                                    明文数据  │
      │ 10.1.0.5 → 10.2.0.10                               │
      │                                                      │
加密前: IP包内容可见                           解密后: 恢复原始IP包
```

## 二、IPsec VPN的三层架构

### 1. **控制层（IKE协议）** - 协商和管理
### 2. **数据层（ESP/AH协议）** - 加密和传输
### 3. **策略层（SPD/SAD）** - 决策和路由

---

## 三、完整的VPN建立和数据传输流程

### 阶段0：配置和准备

```
配置文件 (swanctl.conf):
┌─────────────────────────────────────────────────────┐
│ connections {                                       │
│   net-net {                                         │
│     remote_addrs = 192.168.0.2                      │
│     local {                                         │
│       auth = pubkey                                 │
│       certs = moonCert.pem                          │
│     }                                               │
│     children {                                      │
│       net-net {                                     │
│         local_ts  = 10.1.0.0/16  ← 本地流量选择器  │
│         remote_ts = 10.2.0.0/16  ← 远程流量选择器  │
│         esp_proposals = aes256-sha256               │
│       }                                             │
│     }                                               │
│   }                                                 │
│ }                                                   │
└─────────────────────────────────────────────────────┘

证书准备：
- CA证书：strongswanCert.pem (双方都需要)
- 网关Moon证书：moonCert.pem + moonKey.pem
- 网关Sun证书：sunCert.pem + sunKey.pem
```

### 阶段1：IKE_SA_INIT（初始密钥交换）

**目的**：协商加密算法、交换密钥材料、建立IKE安全关联

```
步骤详解：

发起方Moon                                    响应方Sun
────────                                      ────────

1. 准备提案列表
   ┌─────────────────────────┐
   │ 提案1: aes256-sha256-modp2048  │
   │ 提案2: aes128-sha256-modp2048  │
   │ 提案3: aes256-sha1-modp1536    │
   └─────────────────────────┘
   
2. 生成随机数和DH密钥对
   Ni = 随机生成256位随机数
   私钥 a = 随机生成
   公钥 g^a mod p (MODP 2048位)

3. 发送IKE_SA_INIT请求 ────────────────►
   ┌──────────────────────────┐
   │ HDR (SPIi, SPIr=0)       │
   │ SA载荷 (提案列表)         │
   │ KEi载荷 (g^a)            │  
   │ Ni载荷 (随机数Ni)        │
   └──────────────────────────┘
                                         4. 接收并解析请求
                                            - 提取提案列表
                                            - 提取DH公钥 g^a
                                            - 提取随机数 Ni
                                         
                                         5. 选择匹配的提案
                                            遍历本地配置的提案
                                            与收到的提案逐一匹配
                                            ✓ 选中：aes256-sha256-modp2048
                                         
                                         6. 生成自己的密钥材料
                                            Nr = 随机生成256位
                                            私钥 b = 随机生成
                                            公钥 g^b mod p
                                         
                                         7. 计算DH共享密钥
                                            shared_secret = (g^a)^b mod p
                                                          = g^(ab) mod p
                                         
   ◄────────────────────────── 8. 发送IKE_SA_INIT响应
                               ┌──────────────────────────┐
                               │ HDR (SPIi, SPIr)         │
                               │ SA载荷 (选中的提案)       │
                               │ KEr载荷 (g^b)            │
                               │ Nr载荷 (随机数Nr)        │
                               └──────────────────────────┘

9. 计算DH共享密钥
   shared_secret = (g^b)^a mod p
                 = g^(ab) mod p
   ✓ 双方现在拥有相同的共享密钥！

10. 派生IKE密钥
    ┌──────────────────────────────────┐
    │ SKEYSEED = prf(Ni | Nr, g^ab)    │
    └──────────────────────────────────┘
           ↓
    使用PRF+扩展函数生成密钥材料：
    ┌──────────────────────────────────┐
    │ SK_d  - 用于派生Child SA密钥     │
    │ SK_ai - IKE认证密钥(发起方→响应) │
    │ SK_ar - IKE认证密钥(响应→发起方) │
    │ SK_ei - IKE加密密钥(发起方→响应) │
    │ SK_er - IKE加密密钥(响应→发起方) │
    │ SK_pi - AUTH载荷密钥(发起方)     │
    │ SK_pr - AUTH载荷密钥(响应方)     │
    └──────────────────────────────────┘

✓ IKE SA建立完成，后续消息都将被加密！
```

### 阶段2：IKE_AUTH（身份认证）

**目的**：认证双方身份、协商ESP参数、建立Child SA

```
发起方Moon                                    响应方Sun
────────                                      ────────

11. 准备认证数据
    ID载荷 = "CN=moon.strongswan.org"
    计算AUTH = prf(SK_pi, 签名数据)
    使用私钥签名：sign(moonKey, hash(init_msg))

12. 准备ESP提案
    TSi = 10.1.0.0/16 (本地流量选择器)
    TSr = 10.2.0.0/16 (远程流量选择器)
    ESP提案 = aes256-sha256

13. 发送IKE_AUTH请求 (加密) ─────────────►
    ┌─────────────────────────────────┐
    │ HDR (加密标志)                   │
    │ SK {                            │
    │   IDi (moon的身份)              │
    │   CERT (moon证书)               │
    │   AUTH (签名)                   │
    │   SA (ESP提案)                  │
    │   TSi (10.1.0.0/16)             │
    │   TSr (10.2.0.0/16)             │
    │ }                               │
    └─────────────────────────────────┘
    使用SK_ei和SK_ai加密和认证
                                         14. 解密并验证
                                             使用SK_ei解密
                                             使用SK_ai验证完整性
                                         
                                         15. 验证证书和签名
                                             验证moon证书 → CA证书
                                             验证签名 → moon公钥
                                             ✓ 身份验证通过！
                                         
                                         16. 选择ESP提案
                                             同意使用aes256-sha256
                                         
                                         17. 派生ESP密钥
                                             使用SK_d派生：
                                             ┌─────────────────────┐
                                             │ ESP_SK_ei (加密↑)   │
                                             │ ESP_SK_ai (认证↑)   │
                                             │ ESP_SK_er (加密↓)   │
                                             │ ESP_SK_ar (认证↓)   │
                                             └─────────────────────┘
                                         
   ◄────────────────────────── 18. 发送IKE_AUTH响应 (加密)
                               ┌─────────────────────────────┐
                               │ HDR (加密标志)               │
                               │ SK {                        │
                               │   IDr (sun的身份)           │
                               │   CERT (sun证书)            │
                               │   AUTH (签名)               │
                               │   SA (接受的ESP提案)        │
                               │   TSi, TSr                  │
                               │ }                           │
                               └─────────────────────────────┘

19. 验证sun的身份
    ✓ 证书验证通过
    ✓ 签名验证通过

20. 派生ESP密钥（同样的算法）
    双方现在拥有相同的ESP密钥！

21. 安装安全策略（SPD）和安全关联（SAD）
    SPD: 10.1.0.0/16 ↔ 10.2.0.0/16 使用ESP
    SAD: SPI=0x12345678, ESP密钥, 算法参数

✓ VPN隧道建立完成！可以开始传输数据
```

### 阶段3：数据传输（ESP封装）

**这是真正的数据保护阶段**

```
原始IP包传输过程：

1. 应用层产生数据
   ┌─────────────────────────────────────┐
   │ 用户PC: 10.1.0.5                     │
   │ 应用：curl http://10.2.0.10/api     │
   └─────────────────────────────────────┘
           ↓ 生成HTTP请求

2. 网络层生成IP包
   ┌───────────────────────────────────────┐
   │ 原始IP包                               │
   ├───────────────────────────────────────┤
   │ IP头: src=10.1.0.5, dst=10.2.0.10    │
   │ TCP头: sport=54321, dport=80          │
   │ 数据: GET /api HTTP/1.1...            │
   └───────────────────────────────────────┘
           ↓

3. 到达网关Moon，检查SPD策略
   查询：10.1.0.5 → 10.2.0.10
   匹配策略：10.1.0.0/16 ↔ 10.2.0.0/16
   动作：使用ESP加密（SPI=0x12345678）

4. ESP封装和加密（核心！）
   
   步骤4.1: ESP头部构造
   ┌────────────────────┐
   │ SPI: 0x12345678    │ ← 安全参数索引
   │ Sequence: 42       │ ← 序列号（防重放）
   └────────────────────┘
   
   步骤4.2: 准备加密的载荷
   ┌─────────────────────────────────────┐
   │ 原始IP包（完整）                     │
   │ ESP Trailer (填充 + 下一头部)        │
   └─────────────────────────────────────┘
           ↓ 使用ESP_SK_ei加密
   
   步骤4.3: 加密
   使用AES-256-CBC：
   - 密钥：ESP_SK_ei (32字节)
   - IV：随机生成16字节
   - 加密算法：AES-CBC
   
   ┌─────────────────────────────────────┐
   │ IV (16字节)                          │
   │ 加密的载荷 (乱码)                    │
   └─────────────────────────────────────┘
   
   步骤4.4: 计算认证码
   使用HMAC-SHA256：
   - 密钥：ESP_SK_ai (32字节)
   - 数据：ESP头 + IV + 加密载荷
   
   ICV = HMAC-SHA256(ESP_SK_ai, 全部数据)
   
   步骤4.5: 完整的ESP包
   ┌─────────────────────────────────────┐
   │ ESP Header (SPI + Seq)              │
   │ IV (16字节)                          │
   │ 加密的载荷 (原始IP包已加密)          │
   │ ICV (16字节认证码)                   │
   └─────────────────────────────────────┘

5. IP隧道封装（新的外部IP头）
   ┌─────────────────────────────────────┐
   │ 新IP头: src=192.168.0.1 (Moon)      │
   │        dst=192.168.0.2 (Sun)        │
   │        protocol=ESP (50)            │
   ├─────────────────────────────────────┤
   │ ESP Header (SPI + Seq)              │
   │ IV                                  │
   │ 加密的载荷                           │
   │ ICV                                 │
   └─────────────────────────────────────┘
           ↓ 发送到Internet

6. 通过Internet传输
   任何中间路由器或窃听者只能看到：
   - 外部IP：192.168.0.1 → 192.168.0.2
   - ESP协议包（内容全是加密的乱码）
   ✓ 无法知道真实的源/目的地（10.1.0.5 → 10.2.0.10）
   ✓ 无法知道传输的内容
   ✓ 无法篡改（ICV保护）

7. Sun网关接收并解密
   
   步骤7.1: 收到ESP包
   查找SAD：根据SPI=0x12345678找到对应的SA
   获取：ESP_SK_er（解密密钥）、ESP_SK_ar（认证密钥）
   
   步骤7.2: 验证完整性
   计算：ICV' = HMAC-SHA256(ESP_SK_ar, 接收的数据)
   比较：ICV' == ICV?
   ✓ 完整性验证通过！数据未被篡改
   
   步骤7.3: 检查序列号
   检查Seq=42是否在窗口内，防重放攻击
   ✓ 序列号有效
   
   步骤7.4: 解密
   使用AES-256-CBC解密：
   - 密钥：ESP_SK_er
   - IV：从包中提取
   
   解密后得到：
   ┌───────────────────────────────────────┐
   │ 原始IP包                               │
   │ IP头: src=10.1.0.5, dst=10.2.0.10    │
   │ TCP头: sport=54321, dport=80          │
   │ 数据: GET /api HTTP/1.1...            │
   └───────────────────────────────────────┘
   
   步骤7.5: 转发到内部网络
   路由到10.2.0.10
   ✓ 目标服务器收到原始请求！

8. 返回流量（Sun → Moon）
   使用相同的过程，但使用反向密钥：
   - 加密：ESP_SK_er
   - 认证：ESP_SK_ar
```

## 四、密钥体系详解

### 两套完全独立的密钥

```
┌─────────────────────────────────────────────────────────┐
│                  IKE密钥 (保护控制消息)                  │
├─────────────────────────────────────────────────────────┤
│ SK_ei/SK_er : 加密IKE协议消息                            │
│ SK_ai/SK_ar : 认证IKE协议消息                            │
│ SK_pi/SK_pr : 签名AUTH载荷                               │
│ SK_d        : 派生ESP密钥的主密钥                        │
│                                                         │
│ 用途：保护协商过程本身                                   │
│ 生命周期：几小时到几天                                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                  ESP密钥 (保护用户数据)                  │
├─────────────────────────────────────────────────────────┤
│ ESP_SK_ei : 加密发起方→响应方的数据                      │
│ ESP_SK_ai : 认证发起方→响应方的数据                      │
│ ESP_SK_er : 加密响应方→发起方的数据                      │
│ ESP_SK_ar : 认证响应方→发起方的数据                      │
│                                                         │
│ 用途：保护实际的IP数据包                                 │
│ 生命周期：较短，支持定期重密钥                           │
└─────────────────────────────────────────────────────────┘

派生关系：
DH交换 → SKEYSEED → IKE密钥（包括SK_d）→ ESP密钥
```

### 密钥派生详细过程

```
阶段1：IKE_SA_INIT - 派生IKE SA密钥
======================================

输入材料：
  - DH共享密钥：g^(ab) mod p
  - 发起方随机数：Ni
  - 响应方随机数：Nr

步骤1：计算SKEYSEED
  SKEYSEED = prf(Ni | Nr, g^ir)
  └─ 使用协商的PRF（如PRF-HMAC-SHA256）
  └─ 密钥：Ni | Nr（两个随机数拼接）
  └─ 数据：DH共享密钥

步骤2：使用PRF+派生IKE密钥材料
  seed = Ni | Nr | SPIi | SPIr
  
  keymat = PRF+(SKEYSEED, seed)
  
  // PRF+是一个扩展函数，可以生成任意长度的密钥材料
  // T1 = PRF(SKEYSEED, seed | 0x01)
  // T2 = PRF(SKEYSEED, T1 | seed | 0x02)
  // T3 = PRF(SKEYSEED, T2 | seed | 0x03)
  // keymat = T1 | T2 | T3 | ...

步骤3：分割密钥材料，得到7个IKE密钥
  从keymat中依次提取：
  
  ┌────────────────────────────────────────────────────┐
  │  IKE SA密钥（7个）                                  │
  ├────────────────────────────────────────────────────┤
  │  1. SK_d  (32字节)  - 用于后续派生Child SA密钥     │
  │  2. SK_ai (32字节)  - IKE完整性密钥（发起方→响应方）│
  │  3. SK_ar (32字节)  - IKE完整性密钥（响应方→发起方）│
  │  4. SK_ei (32字节)  - IKE加密密钥（发起方→响应方）  │
  │  5. SK_er (32字节)  - IKE加密密钥（响应方→发起方）  │
  │  6. SK_pi (32字节)  - AUTH载荷密钥（发起方）        │
  │  7. SK_pr (32字节)  - AUTH载荷密钥（响应方）        │
  └────────────────────────────────────────────────────┘

  // 使用示例：AES-256 + HMAC-SHA256
  keymat长度 = 3×32 + 32 + 32 + 32 + 32 = 224字节


阶段2：CREATE_CHILD_SA - 派生ESP密钥
======================================

输入材料：
  - SK_d：从IKE SA密钥中取出
  - 新的随机数：Ni (新), Nr (新)
  - 可选：新的DH共享密钥（如果使用PFS）

步骤1：使用SK_d派生ESP密钥
  seed = [g^ir (新)] | Ni (新) | Nr (新)
  
  keymat = PRF+(SK_d, seed)
  └─ 注意：这里用SK_d作为密钥，不是SKEYSEED

步骤2：分割密钥材料，得到4个ESP密钥
  
  ┌────────────────────────────────────────────────────┐
  │  Child SA密钥（ESP密钥，4个）                       │
  ├────────────────────────────────────────────────────┤
  │  1. SK_ei (32字节)  - ESP加密密钥（发起方→响应方）  │
  │  2. SK_ai (32字节)  - ESP完整性密钥（发起方→响应方）│
  │  3. SK_er (32字节)  - ESP加密密钥（响应方→发起方）  │
  │  4. SK_ar (32字节)  - ESP完整性密钥（响应方→发起方）│
  └────────────────────────────────────────────────────┘

  // 使用示例：AES-256 + HMAC-SHA256
  keymat长度 = 32 + 32 + 32 + 32 = 128字节
```

## 五、安全保障机制

### 1. 机密性（Confidentiality）
```
✓ AES-256加密所有数据
✓ 窃听者只能看到加密的乱码
✓ 即使截获数据包也无法解密（需要密钥）
```

### 2. 完整性（Integrity）
```
✓ HMAC-SHA256认证
✓ 任何篡改都会被检测到
✓ ICV验证失败则丢弃包
```

### 3. 认证（Authentication）
```
✓ 基于证书的身份验证
✓ PKI体系保证身份真实性
✓ 防止中间人攻击
```

### 4. 防重放（Anti-Replay）
```
✓ 序列号机制
✓ 滑动窗口检测
✓ 防止旧包被重新发送
```

### 5. 前向保密（Perfect Forward Secrecy）
```
✓ 每次协商使用新的DH密钥对
✓ 即使长期密钥泄露，历史会话仍然安全
✓ 每个会话独立的密钥
```

## 六、安全策略和安全关联

### SPD（Security Policy Database）- 安全策略数据库

```
┌─────────────────────────────────────────────────────┐
│  SPD条目示例                                         │
├─────────────────────────────────────────────────────┤
│  流量选择器：                                        │
│    源地址：10.1.0.0/16                              │
│    目的地址：10.2.0.0/16                            │
│    协议：任意                                        │
│    端口：任意                                        │
│                                                     │
│  动作：PROTECT（使用IPsec保护）                     │
│                                                     │
│  安全协议：ESP                                       │
│  模式：隧道模式                                      │
│  对端网关：192.168.0.2                              │
└─────────────────────────────────────────────────────┘

工作流程：
1. 数据包到达网关
2. 查询SPD：匹配流量选择器
3. 执行动作：
   - BYPASS（绕过，不加密）
   - DISCARD（丢弃）
   - PROTECT（使用IPsec保护，查询SAD）
```

### SAD（Security Association Database）- 安全关联数据库

```
┌─────────────────────────────────────────────────────┐
│  SAD条目示例（出站）                                 │
├─────────────────────────────────────────────────────┤
│  SPI：0x12345678                                    │
│  目的地址：192.168.0.2                              │
│  协议：ESP                                          │
│  模式：隧道模式                                      │
│                                                     │
│  加密算法：AES-256-CBC                              │
│  加密密钥：ESP_SK_ei (32字节)                       │
│                                                     │
│  认证算法：HMAC-SHA256                              │
│  认证密钥：ESP_SK_ai (32字节)                       │
│                                                     │
│  序列号：42 (当前)                                  │
│  生命周期：3600秒或100MB                            │
│  重放窗口：64包                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  SAD条目示例（入站）                                 │
├─────────────────────────────────────────────────────┤
│  SPI：0x87654321                                    │
│  目的地址：192.168.0.1 (本地)                       │
│  协议：ESP                                          │
│  模式：隧道模式                                      │
│                                                     │
│  加密算法：AES-256-CBC                              │
│  加密密钥：ESP_SK_er (32字节)                       │
│                                                     │
│  认证算法：HMAC-SHA256                              │
│  认证密钥：ESP_SK_ar (32字节)                       │
│                                                     │
│  预期序列号：43                                     │
│  重放窗口位图：[已接收包的记录]                     │
└─────────────────────────────────────────────────────┘
```

## 七、ESP包格式详解

### 隧道模式ESP包结构

```
┌─────────────────────────────────────────────────────┐
│  新IP头 (外部IP头)                                   │
│  ┌───────────────────────────────────────────────┐  │
│  │ 版本: IPv4                                    │  │
│  │ 源地址: 192.168.0.1 (Moon网关)                │  │
│  │ 目的地址: 192.168.0.2 (Sun网关)               │  │
│  │ 协议: 50 (ESP)                                │  │
│  │ 其他字段: TTL, 校验和等                       │  │
│  └───────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│  ESP头 (不加密)                                      │
│  ┌───────────────────────────────────────────────┐  │
│  │ SPI (4字节): 0x12345678                       │  │
│  │ 序列号 (4字节): 0x0000002A (42)               │  │
│  └───────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│  IV (初始化向量，不加密)                             │
│  ┌───────────────────────────────────────────────┐  │
│  │ 16字节随机数 (AES-CBC需要)                    │  │
│  └───────────────────────────────────────────────┘  │
├─────────────────────────────────────────────────────┤
│  加密的载荷 ↓↓↓↓↓↓↓↓                                │
│  ┌───────────────────────────────────────────────┐  │
│  │ 原始IP头 (内部)                               │  │
│  │   源地址: 10.1.0.5                            │  │
│  │   目的地址: 10.2.0.10                         │  │
│  │   协议: TCP (6)                               │  │
│  ├───────────────────────────────────────────────┤  │
│  │ TCP头                                         │  │
│  │   源端口: 54321                               │  │
│  │   目的端口: 80                                │  │
│  ├───────────────────────────────────────────────┤  │
│  │ 应用数据                                      │  │
│  │   GET /api HTTP/1.1                           │  │
│  │   Host: 10.2.0.10                             │  │
│  │   ...                                         │  │
│  ├───────────────────────────────────────────────┤  │
│  │ ESP尾部                                       │  │
│  │   填充 (0-255字节，满足块对齐)                │  │
│  │   填充长度 (1字节)                            │  │
│  │   下一头部 (1字节): 4 (IPv4)                  │  │
│  └───────────────────────────────────────────────┘  │
│  加密的载荷 ↑↑↑↑↑↑↑↑                                │
├─────────────────────────────────────────────────────┤
│  ICV (完整性校验值，不加密)                          │
│  ┌───────────────────────────────────────────────┐  │
│  │ HMAC-SHA256截断到16字节                       │  │
│  │ 覆盖：ESP头 + IV + 加密载荷                   │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘

总大小 = 20(新IP头) + 8(ESP头) + 16(IV) + 
         加密载荷长度 + 16(ICV)
```

## 八、重密钥（Rekeying）过程

### 为什么需要重密钥？

```
安全原因：
1. 限制单个密钥加密的数据量
   - 防止密码分析攻击
   - AES-CBC建议：2^32个块后重密钥

2. 限制密钥的使用时间
   - 减少密钥泄露的风险窗口
   - 典型设置：1小时或100MB流量

3. 前向保密
   - 新密钥独立于旧密钥
   - 旧密钥泄露不影响新会话
```

### IKE SA重密钥

```
发起方Moon                                    响应方Sun
────────                                      ────────

1. 检测到需要重密钥
   - 时间到期：IKE SA存活4小时
   - 或手动触发

2. 发起CREATE_CHILD_SA交换 (重密钥IKE SA)
   ────────────────────────────►
   ┌──────────────────────────┐
   │ HDR (加密，使用旧SK_ei)   │
   │ SK {                     │
   │   SA (新IKE提案)         │
   │   Ni (新随机数)          │
   │   KEi (新DH公钥)         │
   │ }                        │
   └──────────────────────────┘
                                         3. 生成新密钥材料
                                            Nr (新), g^b (新)
                                            计算新DH共享密钥
                                         
                                         4. 派生新IKE密钥
                                            新SKEYSEED
                                            新SK_d, SK_ei, SK_er等
                                         
   ◄──────────────────────────── 5. 响应
                               ┌──────────────────────────┐
                               │ HDR (加密，使用旧SK_er)   │
                               │ SK {                     │
                               │   SA (接受)              │
                               │   Nr (新随机数)          │
                               │   KEr (新DH公钥)         │
                               │ }                        │
                               └──────────────────────────┘

6. 计算新IKE密钥
   双方现在有新的IKE SA密钥

7. 切换到新密钥
   后续消息使用新SK_ei/SK_er加密

8. 删除旧IKE SA
   发送DELETE载荷
   ✓ 平滑过渡完成
```

### Child SA (ESP) 重密钥

```
更频繁的重密钥（典型：每30分钟）

1. 检测到需要重密钥
   - 流量达到100MB
   - 或时间到期

2. 发起CREATE_CHILD_SA交换 (重密钥ESP)
   使用当前IKE SA发送
   ────────────────────────────►
   ┌──────────────────────────┐
   │ SK {                     │
   │   SA (新ESP提案)         │
   │   Ni (新)                │
   │   TSi, TSr               │
   │   [KE (可选，PFS)]       │
   │ }                        │
   └──────────────────────────┘

3. 派生新ESP密钥
   使用当前IKE SA的SK_d
   + 新随机数
   + 可选新DH (PFS)
   
4. 安装新ESP SA
   新SPI: 0x98765432
   新密钥：ESP_SK_ei/ai/er/ar (新)

5. 并行运行
   旧SA：处理已有流量
   新SA：处理新流量
   
6. 删除旧ESP SA
   等待旧流量结束
   发送DELETE载荷
   ✓ 无缝切换完成
```

## 九、NAT穿透（NAT-T）

### 问题：ESP与NAT的冲突

```
ESP协议的问题：
┌────────────────────────────────────────────┐
│ ESP头中没有端口信息                         │
│ NAT设备依赖端口做地址转换                   │
│ → ESP包无法通过NAT                          │
└────────────────────────────────────────────┘

典型场景：
家庭用户 ──► 家庭路由器(NAT) ──► Internet ──► VPN服务器
10.0.0.5      192.168.1.1/公网IP                公网IP
```

### 解决方案：NAT-T (NAT Traversal)

```
核心思想：使用UDP封装ESP包

1. NAT检测（IKE_SA_INIT阶段）
   双方交换NAT_DETECTION_SOURCE_IP载荷
   和NAT_DETECTION_DESTINATION_IP载荷
   
   hash1 = hash(SPIi | SPIr | 实际源IP | 端口)
   hash2 = hash(SPIi | SPIr | 看到的源IP | 端口)
   
   if hash1 != hash2:
      检测到NAT！

2. 切换到UDP封装
   从ESP (协议50) → UDP (端口4500)
   
   正常ESP包：
   ┌──────────────────────────┐
   │ IP头 (协议=50)            │
   │ ESP头                    │
   │ 加密载荷                 │
   └──────────────────────────┘
   
   NAT-T ESP包：
   ┌──────────────────────────┐
   │ IP头 (协议=17 UDP)        │
   │ UDP头 (端口=4500)         │
   │ Non-ESP Marker (4字节0)   │ ← 标识，区分IKE/ESP
   │ ESP头                    │
   │ 加密载荷                 │
   └──────────────────────────┘

3. NAT设备处理
   NAT看到：UDP包，端口4500
   正常转换：
   - 源IP：10.0.0.5 → 公网IP
   - 源端口：4500 → 随机端口
   ✓ ESP内容仍然加密，NAT不需要理解

4. Keep-Alive
   定期发送1字节UDP包（0xFF）
   保持NAT映射不超时
   典型间隔：20秒
```

## 十、strongSwan代码实现位置

### 核心组件源码位置

```
IKE协商层：
├── src/libcharon/sa/ikev2/tasks/
│   ├── ike_init.c           # IKE_SA_INIT任务
│   ├── ike_auth.c           # IKE_AUTH任务
│   ├── child_create.c       # CREATE_CHILD_SA任务
│   ├── child_rekey.c        # Child SA重密钥
│   └── ike_rekey.c          # IKE SA重密钥

密钥管理：
├── src/libcharon/sa/ikev2/
│   ├── keymat_v2.c          # 密钥派生（derive_ike_keys）
│   └── task_manager_v2.c    # 任务调度

算法协商：
├── src/libstrongswan/crypto/
│   ├── proposal/
│   │   └── proposal.c       # 提案选择算法
│   └── crypto_factory.c     # 算法工厂

密码算法插件：
├── src/libstrongswan/plugins/
│   ├── openssl/             # OpenSSL插件（推荐）
│   │   ├── openssl_crypter.c      # AES等加密
│   │   ├── openssl_hasher.c       # SHA256等哈希
│   │   └── openssl_diffie_hellman.c  # DH密钥交换
│   ├── aes/                 # 纯软件AES
│   ├── sha2/                # 纯软件SHA2
│   └── gcrypt/              # libgcrypt插件

ESP处理（内核）：
├── 内核XFRM子系统 (Linux kernel)
│   ├── net/xfrm/            # IPsec核心
│   ├── net/ipv4/esp4.c      # IPv4 ESP
│   └── net/ipv6/esp6.c      # IPv6 ESP

ESP处理（用户态）：
├── src/libipsec/            # 用户态ESP实现
│   ├── esp_packet.c         # ESP包处理
│   └── ipsec_sa.c           # SA管理

配置管理：
├── src/libcharon/config/
│   ├── ike_cfg.c            # IKE配置
│   └── child_cfg.c          # Child配置

VICI接口（swanctl）：
├── src/libcharon/plugins/vici/
│   ├── vici_dispatcher.c    # 命令分发
│   └── vici_config.c        # 配置加载
```

### 关键函数调用链

```
IKE_SA_INIT阶段：
main()
  └→ charon_start()
      └→ task_manager_create()
          └→ ike_init_create()
              ├→ build_payloads()           # 构造SA载荷
              │   └→ get_proposals()        # 获取提案列表
              └→ process_payloads()         # 处理响应
                  ├→ select_proposal()      # 选择提案
                  └→ derive_keys()          # 派生密钥
                      └→ prf_plus()         # PRF+扩展

密钥派生：
derive_ike_keys()  (keymat_v2.c:240)
  ├→ create_prf()                    # 创建PRF实例
  ├→ prf->set_key(Ni|Nr)             # 设置PRF密钥
  ├→ prf->get_bytes(g^ab, skeyseed)  # 计算SKEYSEED
  └→ prf_plus(skeyseed, ...)         # 扩展生成所有密钥
      └→ 循环调用PRF，生成T1, T2, T3...

ESP密钥派生：
derive_child_keys()  (keymat_v2.c:440)
  └→ prf_plus(SK_d, Ni|Nr|...)      # 使用SK_d派生

算法实例化：
create_crypter(ENCR_AES_CBC, 256)
  └→ crypto_factory.c:create_crypter()
      └→ 遍历已注册插件
          └→ openssl_plugin.c:create_crypter()
              └→ openssl_crypter_create()
                  └→ EVP_CIPHER_CTX_new()  # OpenSSL API

ESP封装（内核XFRM）：
发送路径：
ip_output()
  └→ xfrm_output()
      └→ esp_output()
          ├→ esp_encrypt()            # 加密
          │   └→ crypto_aead_encrypt()  # 调用内核密码API
          └→ ip_output()              # 发送加密后的包

接收路径：
ip_input()
  └→ xfrm_input()
      └→ esp_input()
          ├→ crypto_aead_decrypt()    # 解密
          └→ ip_input()               # 继续处理解密后的包
```

## 十一、配置示例

### 基础站点到站点VPN

```conf
# /etc/swanctl/swanctl.conf

connections {
    net-net {
        # 远程网关地址
        remote_addrs = 192.168.0.2
        
        # IKE版本（2是推荐版本）
        version = 2
        
        # 本地身份验证
        local {
            auth = pubkey
            certs = moonCert.pem
            id = "C=CH, O=strongSwan, CN=moon.strongswan.org"
        }
        
        # 远程身份验证
        remote {
            auth = pubkey
            id = "C=CH, O=strongSwan, CN=sun.strongswan.org"
        }
        
        # Child SA配置（ESP隧道）
        children {
            net-net {
                # 本地子网
                local_ts = 10.1.0.0/16
                
                # 远程子网
                remote_ts = 10.2.0.0/16
                
                # ESP提案（数据加密）
                esp_proposals = aes256-sha256-modp2048
                
                # 启动动作
                # - trap: 有流量时自动建立
                # - start: 立即建立
                start_action = trap
                
                # 重密钥时间
                rekey_time = 1h
                
                # 生命周期
                life_time = 1h30m
                
                # 模式
                mode = tunnel
            }
        }
        
        # IKE SA参数
        proposals = aes256-sha256-modp2048
        rekey_time = 4h
        
        # DPD（Dead Peer Detection）
        dpd_delay = 30s
    }
}

# 证书和密钥路径
secrets {
    private-moon {
        file = moonKey.pem
    }
}
```

### 远程访问VPN（Road Warrior）

```conf
# VPN服务器配置

connections {
    rw {
        # 动态客户端
        remote_addrs = %any
        
        pools = ippool
        
        local {
            auth = pubkey
            certs = serverCert.pem
            id = vpn.example.com
        }
        
        remote {
            auth = eap-mschapv2
            # 任意客户端ID
            id = %any
        }
        
        children {
            rw {
                local_ts = 0.0.0.0/0
                
                # ESP提案
                esp_proposals = aes256gcm16-aes128gcm16-sha256
                
                # 保护所有流量
                mode = tunnel
            }
        }
        
        # EAP认证
        send_certreq = no
        
        # 版本
        version = 2
    }
}

# IP池配置
pools {
    ippool {
        addrs = 10.10.10.0/24
        dns = 8.8.8.8, 8.8.4.4
    }
}

# EAP密码
secrets {
    eap-user {
        id = user@example.com
        secret = "SecurePassword123"
    }
}
```

### 高级安全配置

```conf
connections {
    secure-net {
        remote_addrs = 192.168.0.2
        
        local {
            auth = pubkey
            certs = moonCert.pem
        }
        
        remote {
            auth = pubkey
            id = "CN=sun.strongswan.org"
        }
        
        children {
            secure {
                local_ts = 10.1.0.0/16
                remote_ts = 10.2.0.0/16
                
                # 强加密提案（仅AES-256-GCM）
                esp_proposals = aes256gcm16-modp4096
                
                # Perfect Forward Secrecy
                # 每次重密钥都进行DH交换
                rekey_time = 30m
                
                # 防重放窗口
                replay_window = 128
                
                # 启用硬件加速
                hw_offload = yes
                
                mode = tunnel
            }
        }
        
        # IKE强加密
        proposals = aes256-sha512-modp4096
        
        # 短重密钥间隔
        rekey_time = 2h
        
        # 严格的证书验证
        send_cert = always
        
        # DPD
        dpd_delay = 10s
        dpd_timeout = 60s
    }
}
```

## 十二、故障排查

### 常用诊断命令

```bash
# 查看连接状态
swanctl --list-conns

# 查看安全关联
swanctl --list-sas

# 查看证书
swanctl --list-certs

# 发起连接
swanctl --initiate --child net-net

# 终止连接
swanctl --terminate --ike net-net

# 重新加载配置
swanctl --load-all

# 查看日志
journalctl -u strongswan -f

# 内核XFRM状态
ip xfrm state
ip xfrm policy
```

### 日志分析

```bash
# 启用详细日志
# /etc/strongswan.conf

charon {
    filelog {
        /var/log/charon.log {
            time_format = %Y-%m-%d %H:%M:%S
            ike_name = yes
            append = no
            default = 2
            ike = 2
            knl = 2
            net = 2
        }
    }
}

# 常见错误模式

# 1. 提案不匹配
"no proposal found"
→ 检查esp_proposals和proposals配置

# 2. 证书验证失败
"certificate validation failed"
→ 检查CA证书、证书链、时间

# 3. 认证失败
"authentication failed"
→ 检查密钥、证书、ID匹配

# 4. NAT检测
"NAT detected, switching to UDP encapsulation"
→ 正常，会自动启用NAT-T

# 5. 重放攻击检测
"replay check failed"
→ 可能时钟不同步或网络延迟
```

## 十三、性能优化

### 硬件加速

```
1. AES-NI（Intel CPU）
   - 硬件AES加密/解密
   - 性能提升10-20倍
   - 自动检测和使用

2. 网卡卸载（Hardware Offload）
   esp_proposals = ...
   hw_offload = yes
   
   - ESP封装/解封装卸载到网卡
   - 减少CPU负载
   - 支持的网卡：Intel X710, Mellanox等

3. 内核优化
   # /etc/sysctl.conf
   net.core.netdev_max_backlog = 5000
   net.ipv4.tcp_max_syn_backlog = 8192
```

### 并发连接优化

```conf
# /etc/strongswan.conf

charon {
    # 工作线程数（CPU核心数 × 1.5）
    threads = 16
    
    # IKE SA数量限制
    ikesa_table_size = 2048
    ikesa_table_segments = 64
    
    # 加密操作并发
    crypto_workers = 8
    
    # 包处理队列
    process_route = yes
    install_routes = yes
}
```

## 十四、总结

### VPN的本质

VPN通过**三个核心机制**实现安全通信：

1. **密钥协商（IKE）**
   - Diffie-Hellman密钥交换
   - 证书认证身份
   - 协商加密算法

2. **数据加密（ESP）**
   - AES加密保护数据机密性
   - HMAC认证保证数据完整性
   - 序列号防止重放攻击

3. **策略路由（SPD/SAD）**
   - 决定哪些流量需要保护
   - 如何封装和路由
   - 管理安全关联生命周期

### 安全保障

```
机密性 ✓ - 加密防窃听
完整性 ✓ - HMAC防篡改
认证性 ✓ - 证书验证身份
抗重放 ✓ - 序列号检测
前向保密 ✓ - 定期重密钥
可用性 ✓ - DPD检测故障
```

### 关键技术点

- **双层密钥**：IKE密钥保护控制平面，ESP密钥保护数据平面
- **提案协商**：灵活支持多种算法组合
- **隧道封装**：原始IP包完全隐藏在加密隧道中
- **NAT穿透**：UDP封装解决NAT兼容性
- **重密钥**：定期更新密钥保证长期安全

---

**创建日期**: 2025-10-28  
**作者**: GitHub Copilot  
**基于**: strongSwan IPsec VPN实现
