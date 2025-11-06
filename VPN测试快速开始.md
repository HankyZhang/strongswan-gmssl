# VPN 国密算法测试 - 快速开始

## 📋 测试环境

- **本地客户端**: Windows + Docker (strongswan-gmssl:3.1.1)
- **远程服务器**: 101.126.148.5 (Linux)
- **测试算法**: 
  - 标准: RSA + SHA256 + AES256
  - 国密: SM2 + SM3 + SM4

---

## 🚀 快速开始

### 方案 A: 自动化脚本（推荐）

```powershell
# 测试标准算法
.\quick-vpn-test.ps1 -RemoteHost 101.126.148.5

# 测试国密算法
.\quick-vpn-test.ps1 -RemoteHost 101.126.148.5 -UseGMAlgorithm
```

### 方案 B: 分步执行

#### 步骤 1: 生成证书和配置

```powershell
# 标准算法
.\setup-vpn-test.ps1 -RemoteHost 101.126.148.5 -SetupClient -SetupServer

# 国密算法
.\setup-vpn-test.ps1 -RemoteHost 101.126.148.5 -UseGMAlgorithm -SetupClient -SetupServer
```

#### 步骤 2: 在远程服务器安装 strongSwan

```powershell
# 传输安装脚本
scp setup-vpn-server.sh root@101.126.148.5:/tmp/

# SSH 连接并安装
ssh root@101.126.148.5
bash /tmp/setup-vpn-server.sh
# 选择 1 (标准) 或 2 (国密)
exit
```

#### 步骤 3: 传输证书到服务器

```powershell
# 传输服务端证书
scp vpn-certs/server-key.pem root@101.126.148.5:/etc/swanctl/private/
scp vpn-certs/server-cert.pem root@101.126.148.5:/etc/swanctl/x509/
scp vpn-certs/ca-cert.pem root@101.126.148.5:/etc/swanctl/x509ca/

# 传输配置文件
scp vpn-certs/ipsec.conf root@101.126.148.5:/etc/ipsec.conf
# 或者国密版本
scp vpn-certs/ipsec.conf root@101.126.148.5:/etc/swanctl/swanctl.conf
```

#### 步骤 4: 启动服务器端服务

```bash
# SSH 到服务器
ssh root@101.126.148.5

# 启动 strongSwan
systemctl restart strongswan
systemctl status strongswan

# 查看配置
swanctl --list-conns
# 或
ipsec statusall
```

#### 步骤 5: 启动客户端

```powershell
# 交互式模式（推荐用于测试）
.\start-vpn-client.ps1 -RemoteHost 101.126.148.5 -Interactive

# 在容器内执行:
swanctl --load-all
swanctl --initiate --child tunnel
swanctl --list-sas
```

---

## 📁 文件说明

| 文件 | 用途 |
|------|------|
| `vpn-test-guide.md` | 详细测试指南（原理、配置、故障排查） |
| `quick-vpn-test.ps1` | 一键测试脚本 |
| `setup-vpn-test.ps1` | 生成证书和配置 |
| `setup-vpn-server.sh` | 服务器端安装脚本 |
| `start-vpn-client.ps1` | 启动客户端 |
| `vpn-certs/` | 生成的证书目录 |

---

## 🧪 测试验证

### 1. 检查连接状态

```bash
# 在客户端容器内
swanctl --list-sas

# 预期输出
gmsm-client: #1, ESTABLISHED, IKEv2
  local  'vpn-client' @ 192.168.x.x
  remote '$RemoteHost' @ 101.126.148.5
  established 123s ago
```

### 2. 验证使用的算法

```bash
# 查看加密套件
swanctl --list-sas | grep -E "encr|integ|prf"

# 国密版本应显示:
#   encr: SM4_CBC
#   integ: SM3_HMAC
#   prf: PRF_SM3_HMAC
```

### 3. 测试网络连通性

```bash
# ping 服务器内网 IP
ping 10.10.10.1

# 或测试互联网（如果服务器配置了 NAT）
ping 8.8.8.8
```

### 4. 抓包验证加密流量

```bash
# 在服务器端
tcpdump -i any esp -n

# 应该看到 ESP 协议的加密包
```

---

## ⚠️ 常见问题

### 问题 1: 连接超时

**原因**: 防火墙阻止 UDP 500/4500 端口

**解决**:
```bash
# 在服务器上
ufw allow 500/udp
ufw allow 4500/udp
```

### 问题 2: 认证失败

**原因**: 证书不匹配或配置错误

**解决**:
```bash
# 检查证书
gmssl certparse -in /etc/swanctl/x509/server-cert.pem

# 检查配置
swanctl --list-conns
```

### 问题 3: 国密算法不支持

**原因**: 服务器端未安装国密版本 strongSwan

**解决**: 在服务器上执行 `setup-vpn-server.sh` 选择选项 2 (国密版本)

---

## 📊 性能测试

### 使用 iperf3 测试

```bash
# 服务器端
apt-get install -y iperf3
iperf3 -s

# 客户端 (在 Docker 容器内)
apt-get update && apt-get install -y iperf3
iperf3 -c 10.10.10.1 -t 30
```

### 对比标准算法 vs 国密算法

1. 测试标准算法 (AES256-SHA256)
2. 重新配置为国密算法 (SM2-SM3-SM4)
3. 对比吞吐量、延迟、CPU 占用

---

## 🔍 调试技巧

### 查看详细日志

```bash
# strongSwan 日志
journalctl -u strongswan -f

# 或在容器内
tail -f /var/log/syslog
```

### 增加调试级别

编辑 `/etc/strongswan.conf`:

```conf
charon {
    filelog {
        /var/log/charon.log {
            time_format = %b %e %T
            default = 2
            ike = 3
            cfg = 3
        }
    }
}
```

---

## 📈 测试报告模板

```
测试日期: 2025-11-06
测试算法: [ ] 标准  [✓] 国密

环境信息:
- 客户端: Windows 11 + Docker
- 服务器: Ubuntu 22.04 @ 101.126.148.5
- strongSwan 版本: 6.0.3 (国密)

连接测试:
- [✓] IKE SA 建立成功
- [✓] ESP SA 建立成功
- [✓] 使用 SM2/SM3/SM4 算法
- [✓] 网络流量正常

性能测试:
- 吞吐量: _____ Mbps
- 延迟: _____ ms
- 丢包率: _____ %

备注:
_______________________
```

---

## 📚 参考资料

- [完整测试指南](./vpn-test-guide.md)
- [国密插件快速开始](./gmsm插件快速开始.md)
- [代码更改详细对比](./代码更改详细对比报告.md)
- [Docker 构建优化说明](./Docker构建优化说明.md)

---

## 💡 提示

1. **首次测试建议**: 先使用标准算法验证连通性，再切换到国密算法
2. **证书管理**: 妥善保管私钥文件，生产环境建议使用更长的有效期
3. **网络环境**: 确保客户端和服务器可以直接通信（无 NAT 限制）
4. **性能优化**: 生产环境建议使用硬件加密加速

---

**创建时间**: 2025-11-06  
**版本**: 1.0  
**维护者**: strongSwan-GmSSL Team
