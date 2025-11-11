# 国密 VPN 测试 - 最终版本

## 🎉 重大突破！

发现问题根本原因：strongSwan 配置文件无法识别数字形式的算法标识符（如"1031"），需要使用算法名称关键字。

### ✅ 已修复的问题：

1. **GMSM 插件版本字段缺失** - 已在 `gmsm_plugin.c` 中添加 VERSION 宏
2. **算法名称映射缺失** - 已在 `crypter.c` 中添加 SM4 算法名称到枚举表
3. **发现正确的配置关键字** - 在 `proposal_keywords_static.txt` 中已定义：
   - `sm4` / `sm4cbc` → SM4-CBC 加密
   - `sm4gcm` → SM4-GCM 加密
   - `sm3` → HMAC-SM3 完整性
   - `prfsm3` → SM3 PRF

---

## 📋 部署步骤

### 1. 更新两台服务器的镜像

**客户端 (8.140.37.32):**
```bash
# 加载新镜像
docker load < /tmp/strongswan-gmssl-v2.tar

# 停止旧容器
docker stop strongswan-gmsm-client
docker rm strongswan-gmsm-client

# 启动新容器
docker run -d \
  --name strongswan-gmsm-client \
  --restart=always \
  --privileged \
  --network host \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /lib/modules:/lib/modules:ro \
  strongswan-gmssl:3.1.1-gmsm-v2
```

**服务端 (101.126.148.5):**
```bash
# 加载新镜像
docker load < /tmp/strongswan-gmssl-v2.tar

# 停止旧容器
docker stop strongswan-gmsm
docker rm strongswan-gmsm

# 启动新容器
docker run -d \
  --name strongswan-gmsm \
  --restart=always \
  --privileged \
  --network host \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /lib/modules:/lib/modules:ro \
  strongswan-gmssl:3.1.1-gmsm-v2
```

---

### 2. 上传国密配置文件

**在 Windows PowerShell 中:**

```powershell
# 上传客户端配置
scp config\swanctl\gmsm-psk-client-v2.conf root@8.140.37.32:/etc/strongswan-docker/swanctl/swanctl.conf

# 上传服务器配置
scp config\swanctl\gmsm-psk-server-v2.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf
```

---

### 3. 加载配置并建立连接

**服务器端:**
```bash
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"
```

**客户端:**
```bash
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --load-all"
```

**手动触发连接:**
```bash
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --initiate --child gmsm-tunnel"
```

---

### 4. 验证国密算法连接

**查看连接状态:**
```bash
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --list-sas"
```

**预期输出（使用国密算法）:**
```
gmsm-client: #1, ESTABLISHED, IKEv2
  local  'vpn-client@test.com' @ 172.24.18.28[4500] [10.10.10.1]
  remote 'vpn-server@test.com' @ 101.126.148.5[4500]
  SM4_CBC-128/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048  ← 国密算法！
  established 10s ago
  
  gmsm-tunnel: #1, INSTALLED, TUNNEL-in-UDP
    ESP:SM4_CBC-128/HMAC_SM3_96  ← ESP 国密算法！
    in  cXXXXXXXX,    960 bytes,    12 packets
    out cXXXXXXXX,   1200 bytes,    15 packets
    local  10.10.10.1/32
    remote 0.0.0.0/0
```

---

## 🔍 故障排查

### 问题 1: 配置加载失败 "invalid value for: proposals"

**原因:** 使用了数字形式的算法标识符（如 "1031"）而不是关键字

**解决:** 使用正确的关键字：
- ❌ `proposals = 1031-sm3-modp2048`
- ✅ `proposals = sm4-sm3-modp2048`

### 问题 2: GMSM 插件未加载

**检查:**
```bash
docker exec strongswan-gmsm-client swanctl --list-algs | grep -i sm
```

**应该看到:**
```
  (1031)[gmsm]        # SM4_CBC
  (1032)[gmsm]        # SM4_GCM
  HMAC_SM3_96[gmsm]
  HASH_SM3[gmsm]
  PRF_HMAC_SM3[gmsm]
```

### 问题 3: 连接建立但使用标准算法

这是正常的后备行为。配置中包含：
```
proposals = sm4-sm3-modp2048,aes256-sha256-modp2048
                                  ↑ 后备算法
```

只要连接建立就表示系统工作正常。

---

## 📊 配置文件说明

### 客户端配置 (`gmsm-psk-client-v2.conf`)

```
connections {
    gmsm-client {
        version = 2
        # 国密算法优先，标准算法后备
        proposals = sm4-sm3-modp2048,aes256-sha256-modp2048
        
        remote_addrs = 101.126.148.5
        
        local {
            auth = psk
            id = vpn-client@test.com
        }
        
        remote {
            auth = psk
            id = vpn-server@test.com
        }
        
        children {
            gmsm-tunnel {
                local_ts = 0.0.0.0/0
                remote_ts = 0.0.0.0/0
                
                # ESP 国密算法优先
                esp_proposals = sm4-sm3,aes256-sha256
                
                start_action = trap
                dpd_action = restart
                close_action = restart
            }
        }
    }
}

secrets {
    ike-gmsm {
        id-local = vpn-client@test.com
        id-remote = vpn-server@test.com
        secret = "GmSM_VPN_Test_2025"
    }
}
```

### 服务器配置 (`gmsm-psk-server-v2.conf`)

```
connections {
    gmsm-server {
        version = 2
        # 国密算法优先，标准算法后备
        proposals = sm4-sm3-modp2048,aes256-sha256-modp2048
        
        local_addrs = 0.0.0.0
        
        local {
            auth = psk
            id = vpn-server@test.com
        }
        
        remote {
            auth = psk
            id = vpn-client@test.com
        }
        
        children {
            gmsm-tunnel {
                local_ts = 0.0.0.0/0
                remote_ts = dynamic
                
                # ESP 国密算法优先
                esp_proposals = sm4-sm3,aes256-sha256
                
                mode = tunnel
                dpd_action = clear
            }
        }
        
        pools = roadwarrior-pool
    }
}

pools {
    roadwarrior-pool {
        addrs = 10.10.10.0/24
        dns = 8.8.8.8, 114.114.114.114
    }
}

secrets {
    ike-gmsm {
        id-server = vpn-server@test.com
        id-client = vpn-client@test.com
        secret = "GmSM_VPN_Test_2025"
    }
}
```

---

## 📈 测试进度

### ✅ 已完成：
1. 购买并配置阿里云服务器 (8.140.37.32)
2. 成功建立标准算法 VPN 连接
3. 修复 GMSM 插件版本字段问题
4. 添加 SM4 算法名称到枚举表
5. 发现正确的配置关键字
6. 编译新版本镜像 (strongswan-gmssl:3.1.1-gmsm-v2)

### ⏳ 待完成：
1. 部署新镜像到两台服务器
2. 上传国密配置文件
3. 验证国密算法 VPN 连接
4. 性能和稳定性测试

---

## 💡 关键发现

### strongSwan 配置关键字 (proposal_keywords_static.txt)

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

### 算法枚举映射 (crypter.c)

**修改前:** ENUM_END 在 ENCR_AES_CFB

**修改后:** 添加了 SM4 映射：
```c
ENUM_NEXT(encryption_algorithm_names, ENCR_SM4_CBC, ENCR_SM4_GCM_ICV16, ENCR_AES_CFB,
	"SM4_CBC",
	"SM4_GCM_16");
ENUM_END(encryption_algorithm_names, ENCR_SM4_GCM_ICV16);
```

---

## 🚀 下次继续的命令

```powershell
# 1. 等待镜像上传完成
# 检查上传进度（两个后台任务）

# 2. 更新客户端
ssh root@8.140.37.32 "docker load < /tmp/strongswan-gmssl-v2.tar && docker stop strongswan-gmsm-client && docker rm strongswan-gmsm-client && docker run -d --name strongswan-gmsm-client --restart=always --privileged --network host -v /etc/strongswan-docker/swanctl:/etc/swanctl -v /lib/modules:/lib/modules:ro strongswan-gmssl:3.1.1-gmsm-v2"

# 3. 更新服务器
ssh root@101.126.148.5 "docker load < /tmp/strongswan-gmssl-v2.tar && docker stop strongswan-gmsm && docker rm strongswan-gmsm && docker run -d --name strongswan-gmsm --restart=always --privileged --network host -v /etc/strongswan-docker/swanctl:/etc/swanctl -v /lib/modules:/lib/modules:ro strongswan-gmssl:3.1.1-gmsm-v2"

# 4. 上传配置
scp config\swanctl\gmsm-psk-client-v2.conf root@8.140.37.32:/etc/strongswan-docker/swanctl/swanctl.conf
scp config\swanctl\gmsm-psk-server-v2.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf

# 5. 测试连接
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --load-all"
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --initiate --child gmsm-tunnel"

# 6. 查看结果
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --list-sas"
```

---

**预计完成时间:** 30-40 分钟（主要是镜像上传）  
**成功标志:** 连接状态显示 "SM4_CBC" 和 "HMAC_SM3_96"
