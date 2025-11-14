# strongSwan + GmSSL 最终修复测试指南

## 🎯 问题和修复总结

### 问题 1: plugin 'yes' 加载失败 ✅ 已修复
**错误**: `plugin 'yes': failed to load - yes_plugin_create not found`

**原因**: `strongswan.conf.gmsm` 中 `load_modular = yes` 被错误解析为加载名为 "yes" 的插件

**修复**: 
- 删除 `load_modular = yes`
- 删除 `swanctl { load = yes }`
- 保留显式插件加载配置

### 问题 2: SM4-SM3 算法无法识别 🔄 修复中
**错误**: `invalid value for: proposals` (提案 `sm4-sm3-modp2048` 无效)

**原因**:
1. ✅ GMSM 插件正确编译 (`libstrongswan-gmsm.so` 包含 SM2/SM3/SM4 实现)
2. ✅ `proposal_keywords_static.txt` 包含 SM4/SM3 定义
3. ❌ `proposal_keywords_static.c` 是预生成的旧文件（不含 SM4）
4. ❌ Make 构建系统不会自动重新生成（因为文件已存在）

**修复**:
```dockerfile
# Dockerfile.gmssl 中
RUN rm -f src/libstrongswan/crypto/proposal/proposal_keywords_static.c \
    && touch src/libstrongswan/crypto/proposal/proposal_keywords_static.txt \
    && ./configure ...
```

**构建规则** (`Makefile.in`):
```makefile
$(srcdir)/crypto/proposal/proposal_keywords_static.c: \
    $(srcdir)/crypto/proposal/proposal_keywords_static.txt \
    $(srcdir)/crypto/proposal/proposal_keywords_static.h
    $(GPERF) -N proposal_get_token_static -m 10 -C -G -c -t -D \
        --output-file=$@ $(srcdir)/crypto/proposal/proposal_keywords_static.txt
```

---

## 🐳 Docker 镜像

### 已构建镜像
- `strongswan-gmssl:3.1.1-gmsm-success` - 旧版本（有 plugin 'yes' 错误）
- `strongswan-gmssl:3.1.1-gmsm-fixed` - 修复了配置错误，但算法仍未注册
- `strongswan-gmssl:3.1.1-gmsm-final2` - 🔄 **构建中** - 完整修复

### 重新构建命令
```powershell
docker build -f Dockerfile.gmssl `
  --build-arg CACHE_BUST=$(Get-Date -Format "yyyyMMddHHmmss") `
  -t strongswan-gmssl:3.1.1-gmsm-final2 .
```

---

## 🧪 测试步骤

### 1. 快速测试脚本
```powershell
.\test-gmsm-fixed.ps1
```

### 2. 手动测试命令
```powershell
# 启动容器
docker run --rm -d --name test-gmsm --privileged `
  strongswan-gmssl:3.1.1-gmsm-final2

# 等待服务启动
Start-Sleep -Seconds 3

# 创建测试配置
docker exec test-gmsm bash -c "cat > /etc/swanctl/swanctl.conf << 'EOF'
connections {
    test {
        version = 2
        proposals = sm4-sm3-modp2048
        local_addrs = 0.0.0.0
        local { auth = psk; id = test.local }
        remote { auth = psk }
        children {
            child {
                esp_proposals = sm4-sm3
                local_ts = 0.0.0.0/0
            }
        }
    }
}
secrets {
    ike { id = test.local; secret = test123 }
}
EOF
"

# 测试配置加载
docker exec test-gmsm swanctl --load-conns

# 查看连接详情
docker exec test-gmsm swanctl --list-conns

# 清理
docker stop test-gmsm
```

### 3. 预期结果
```
✅ 无 "plugin 'yes'" 错误信息
✅ 配置加载成功: loaded 1 of 1 connections
✅ 显示完整连接信息:
   - IKE proposals: SM4_CBC/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
   - ESP proposals: SM4_CBC/HMAC_SM3_96
```

### 4. 如果仍然失败
检查 gperf 是否正确生成了包含 SM4 的代码：

```powershell
# 进入容器
docker exec -it test-gmsm bash

# 安装工具
apt-get update && apt-get install -y binutils

# 检查是否包含 SM4 字符串
strings /usr/local/strongswan/lib/libstrongswan.so | grep -i "sm4\|sm3" | head -20
```

---

## 📁 相关文件

### 源代码文件
- `src/libstrongswan/crypto/proposal/proposal_keywords_static.txt` - 算法关键字定义
- `src/libstrongswan/crypto/proposal/proposal_keywords_static.c` - gperf 生成的查找代码
- `src/libstrongswan/plugins/gmsm/` - GMSM 插件实现

### 配置文件
- `config/strongswan.conf.gmsm` - strongSwan 主配置
- `Dockerfile.gmssl` - Docker 镜像构建脚本

### 测试脚本
- `test-gmsm-fixed.ps1` - 自动化测试脚本

### 文档
- `CONFIG-FIX-REPORT.md` - 配置错误修复报告
- `ROOT-CAUSE-ANALYSIS.md` - 根本原因分析

---

## 🔍 调试技巧

### 检查插件加载
```bash
# 列出已加载的插件
swanctl --stats | grep -A 50 "loaded plugins"

# 检查 GMSM 插件文件
ls -lh /usr/local/strongswan/lib/ipsec/plugins/ | grep gmsm
```

### 查看日志
```bash
# charon 启动日志（在容器启动脚本中）
tail -f /var/log/syslog | grep charon

# 或直接启动 charon 查看输出
/usr/local/strongswan/libexec/ipsec/charon
```

### 验证算法注册
```bash
# 检查二进制文件中的算法标识
strings /usr/local/strongswan/lib/libstrongswan.so | grep -E "^(sm4|sm3|sm2)" | sort | uniq
```

---

## ✅ 成功标志

当所有修复完成后，应该看到：

1. **无错误信息**:
   ```
   ✅ 无 "plugin 'yes'" 错误
   ✅ 无 "invalid value for: proposals" 错误
   ```

2. **连接加载成功**:
   ```
   loaded connection 'test'
   loaded 1 of 1 connections, 0 failed to load
   ```

3. **显示完整配置**:
   ```
   test: IKEv2, SM4_CBC/HMAC_SM3_96/PRF_HMAC_SM3/MODP_2048
     local:  0.0.0.0
     remote: %any
     child:  SM4_CBC/HMAC_SM3_96, dpdaction=clear
   ```

---

**最后更新**: 2025-11-12  
**状态**: 🔄 Docker 镜像重新构建中
**预计完成时间**: ~3-5 分钟
