# 🎯 国密 VPN 测试 - 3 分钟快速参考

## 问题是什么？
❌ Windows Docker Desktop 的 VPN 客户端无法连接  
✅ 原因：容器使用 WSL2 内部 IP (192.168.65.3)，服务器无法路由回复

## 解决方案
使用 Linux 服务器作为 VPN 客户端（Docker 的 `--network host` 在 Linux 上才真正有效）

---

## 📋 3 步开始测试

### 1️⃣ 准备客户端环境
```powershell
scp deployment-scripts\setup-client-linux.sh root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "/tmp/setup-client-linux.sh"
```

### 2️⃣ 传输镜像
```powershell
docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar
scp strongswan-gmssl.tar root@<CLIENT_IP>:/tmp/
ssh root@<CLIENT_IP> "docker load -i /tmp/strongswan-gmssl.tar"
```

### 3️⃣ 运行测试
```powershell
.\deployment-scripts\test-gmsm-vpn-linux.ps1 -ClientIP <CLIENT_IP> -Deploy -Test
```

---

## 🔍 5 个常用命令

### 客户端
```bash
# 发起连接
docker exec strongswan-client swanctl --initiate --child gmsm-net

# 查看状态
docker exec strongswan-client swanctl --list-sas

# 测试连通
docker exec strongswan-client ping 10.10.10.1
```

### 服务器
```bash
# 查看状态
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-sas"

# 查看日志
ssh root@101.126.148.5 "docker logs --tail 50 strongswan-gmsm"
```

---

## 📚 文档快速查找

| 需求 | 文档 |
|------|------|
| 快速了解问题 | `docs/Windows-Docker-Issue-SUMMARY.md` |
| 完整测试步骤 | `docs/GMSM-VPN-Testing-Guide.md` |
| 命令速查 | `deployment-scripts/COMMANDS-CHEATSHEET.md` |
| 文档导航 | `docs/README-DOCS.md` |

---

## ✅ 测试检查清单

- [ ] Linux 客户端服务器已准备（记录 IP: ___________）
- [ ] 客户端已执行 setup-client-linux.sh
- [ ] Docker 镜像已传输并加载
- [ ] 服务器端容器运行正常
- [ ] 客户端可以 ping 通服务器 (101.126.148.5)

---

## 🎯 成功标志

**阶段一（标准算法）**:
```
✅ AES_CBC-256/HMAC_SHA2_256_128
✅ gmsm-net: INSTALLED, TUNNEL
✅ ping 10.10.10.1 成功
```

**阶段二（国密算法）**:
```
✅ SM4/HMAC_SM3_96
✅ gmsm-net: INSTALLED, TUNNEL
✅ ping 10.10.10.1 成功
```

---

## 📞 遇到问题？

1. **连接超时** → 检查防火墙: `deployment-scripts/COMMANDS-CHEATSHEET.md`
2. **算法错误** → 查看配置: `docs/GMSM-VPN-Testing-Guide.md`
3. **认证失败** → 检查密钥: 确保两端 PSK 一致
4. **其他问题** → 查看日志: `docker logs strongswan-client`

---

**服务器**: root@101.126.148.5  
**最后更新**: 2025-11-11
