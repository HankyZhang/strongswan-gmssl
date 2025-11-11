# 国密 VPN 测试 - 继续步骤

## 🎉 已完成的工作（今天）

1. ✅ 购买并配置阿里云服务器 (8.140.37.32, 北京)
2. ✅ 安装 Docker 和基础环境
3. ✅ 部署 strongSwan 客户端容器
4. ✅ 验证标准算法 VPN 连接成功 (AES256-SHA256)
5. ✅ 发现并修复 GMSM 插件版本字段问题
6. ✅ 重新编译带修复的 Docker 镜像
7. ✅ 验证 GMSM 插件成功加载 (SM2/SM3/SM4)

---

## 📋 下次继续的步骤

### 步骤 1: 更新服务器端镜像

**在你的 Windows 电脑上：**

```powershell
# 1. 上传修复后的镜像到服务器
scp strongswan-gmssl-fixed.tar root@101.126.148.5:/tmp/

# 2. SSH 登录服务器
ssh root@101.126.148.5

# 3. 加载新镜像
docker load < /tmp/strongswan-gmssl-fixed.tar

# 4. 停止并删除旧容器
docker stop strongswan-gmsm
docker rm strongswan-gmsm

# 5. 启动新容器
docker run -d \
  --name strongswan-gmsm \
  --restart=always \
  --privileged \
  --network host \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /lib/modules:/lib/modules:ro \
  strongswan-gmssl:3.1.1-fixed
```

---

### 步骤 2: 更新服务器端配置（支持国密算法）

**创建服务器端配置文件：`gmsm-psk-server-fixed.conf`**

```
connections {
    gmsm-server {
        version = 2
        # 国密算法优先，标准算法后备
        proposals = 1031-sm3-modp2048,aes256-sha256-modp2048
        
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
            gmsm-net {
                local_ts = 0.0.0.0/0
                remote_ts = dynamic
                
                # ESP 国密算法优先
                esp_proposals = 1031-sm3,aes256-sha256
                
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

**上传并应用配置：**

```powershell
# 1. 上传配置文件
scp config/swanctl/gmsm-psk-server-fixed.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf

# 2. 重启服务器容器
ssh root@101.126.148.5 "docker restart strongswan-gmsm"

# 3. 验证配置加载
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"

# 4. 查看连接定义
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-conns"
```

---

### 步骤 3: 验证国密算法连接

**检查客户端连接：**

```powershell
# 1. 重启客户端容器（触发自动连接）
ssh root@8.140.37.32 "docker restart strongswan-gmsm-client"

# 2. 等待30秒后查看连接状态
ssh root@8.140.37.32 "sleep 30 && docker exec strongswan-gmsm-client swanctl --list-sas"
```

**预期成功输出（使用国密算法）：**

```
gmsm-client: #1, ESTABLISHED, IKEv2
  local  'vpn-client@test.com' @ 172.24.18.28[4500] [10.10.10.1]
  remote 'vpn-server@test.com' @ 101.126.148.5[4500]
  1031/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048  ← 使用 SM4+SM3！
  established 10s ago
  
  gmsm-tunnel: #1, INSTALLED, TUNNEL
    ESP:1031/HMAC_SM3_96  ← ESP 使用 SM4+SM3！
    in  c1234567,      0 bytes,     0 packets
    out c7654321,    960 bytes,    12 packets
    local  10.10.10.1/32
    remote 0.0.0.0/0
```

**如果使用标准算法（后备）：**

```
  AES_CBC-256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048
```

---

### 步骤 4: 网络测试

```powershell
# 1. 从客户端 ping 服务器
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client ping -c 4 10.10.10.254"

# 2. 查看隧道流量统计
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --list-sas --ike gmsm-client"
```

---

## 🎯 成功标志

1. ✅ 连接状态显示 "ESTABLISHED"
2. ✅ 算法显示 "1031" (SM4) 或 "SM4"
3. ✅ 算法显示 "HMAC_SM3_96" 或 "sm3"
4. ✅ 有数据包进出统计
5. ✅ 能够 ping 通虚拟 IP

---

## 🔧 故障排查

### 如果连接失败：

```powershell
# 1. 查看客户端日志
ssh root@8.140.37.32 "docker logs --tail 50 strongswan-gmsm-client"

# 2. 查看服务端日志
ssh root@101.126.148.5 "docker logs --tail 50 strongswan-gmsm"

# 3. 查看配置加载错误
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --load-all"
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --load-all"

# 4. 手动触发连接
ssh root@8.140.37.32 "docker exec strongswan-gmsm-client swanctl --initiate --child gmsm-tunnel"
```

### 如果算法协商失败（使用了标准算法）：

这可能是正常的后备行为。只要连接建立就说明系统工作正常。

国密算法优先级设置：
```
proposals = 1031-sm3-modp2048,aes256-sha256-modp2048
                 ↑ 优先                      ↑ 后备
```

---

## 📊 测试数据记录

### 服务器信息：
- **服务端**: 101.126.148.5 (北京)
- **客户端**: 8.140.37.32 (北京)
- **镜像版本**: strongswan-gmssl:3.1.1-fixed
- **GmSSL 版本**: 3.1.1
- **strongSwan 版本**: 6.0.3dr1

### 当前状态：
- ✅ 标准算法 VPN: 成功 (AES256-SHA256)
- ✅ GMSM 插件: 已加载
- ⏳ 国密算法 VPN: 待测试（需服务器端配置）

---

## 💾 备份重要文件

```powershell
# 1. 备份当前配置
scp root@8.140.37.32:/etc/strongswan-docker/swanctl/swanctl.conf ./backup/client-config-$(Get-Date -Format 'yyyyMMdd').conf
scp root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf ./backup/server-config-$(Get-Date -Format 'yyyyMMdd').conf

# 2. 导出镜像（已完成）
# strongswan-gmssl-fixed.tar (61MB)

# 3. 提交代码到 Git
git add src/libstrongswan/plugins/gmsm/gmsm_plugin.c
git commit -m "修复 GMSM 插件版本字段问题"
git push my-repo master
```

---

## 📚 参考文档

1. **快速部署指南**: `docs/Quick-Start-With-Aliyun-ECS.md`
2. **测试进度报告**: `GMSM-VPN-Testing-Report.md`
3. **完整测试指南**: `docs/Company-Intranet-GMSM-Testing-Guide.md`

---

**下次测试时间**: 随时可以继续  
**预计所需时间**: 15-20 分钟完成服务器端配置和国密算法测试

**联系方式**: 通过 GitHub Issues 或继续对话
