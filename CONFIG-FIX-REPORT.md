# strongSwan 配置错误修复记录

## 问题描述

### 错误现象
```
plugin 'yes': failed to load - yes_plugin_create not found and no plugin file available
loading connection 'test' failed: invalid value for: proposals, config discarded
```

### 测试命令
```powershell
docker run --rm -d --name test-final --privileged strongswan-gmssl:3.1.1-gmsm-success
docker exec test-final swanctl --load-conns
```

### 错误表现
1. **插件加载失败**: `plugin 'yes': failed to load`
2. **算法配置无效**: `invalid value for: proposals` (SM4-SM3 无法识别)
3. **连接加载失败**: `loaded 0 of 1 connections, 1 failed to load`

---

## 根本原因分析

### 配置文件: `/etc/strongswan.conf`

**错误配置**:
```conf
charon {
    load_modular = yes  # ❌ 错误: 被解析为加载名为 "yes" 的插件
    ...
}

swanctl {
    load = yes  # ❌ 错误: swanctl 不是插件，不应该有 load 指令
}
```

### strongSwan 配置解析机制

strongSwan 的配置解析器对 `load_modular` 的处理有歧义：
- **预期行为**: `load_modular = yes` 应启用模块化配置加载
- **实际行为**: strongSwan 尝试加载名为 `yes` 的插件 (`yes_plugin_create`)
- **后果**: 
  1. 插件加载器报错
  2. GMSM 插件可能未正确初始化
  3. SM2/SM3/SM4 算法未注册到提案系统

---

## 解决方案

### 修改配置文件

**正确配置** (`config/strongswan.conf.gmsm`):
```conf
charon {
    # ✅ 移除 load_modular，使用显式插件加载
    threads = 16
    
    plugins {
        gmsm {
            load = yes  # ✅ 正确: 显式加载 GMSM 插件
        }
        
        openssl {
            load = yes
        }
        
        # ... 其他插件
    }
}

# ✅ 移除 swanctl 配置块 (不需要)

libstrongswan {
    plugins {
        gmsm {
            load = yes  # ✅ 库级别也加载 GMSM
        }
    }
}
```

### 修改内容总结
1. ❌ **删除**: `load_modular = yes`
2. ❌ **删除**: `swanctl { load = yes }`
3. ✅ **保留**: `charon.plugins.gmsm { load = yes }`
4. ✅ **保留**: `libstrongswan.plugins.gmsm { load = yes }`

---

## 验证修复

### 重新构建镜像
```powershell
docker build -f Dockerfile.gmssl `
  --build-arg CACHE_BUST=$(Get-Date -Format "yyyyMMddHHmmss") `
  -t strongswan-gmssl:3.1.1-gmsm-fixed .
```

### 测试配置加载
```powershell
# 运行测试脚本
.\test-gmsm-fixed.ps1
```

### 预期结果
```
✅ 无 "plugin 'yes'" 错误
✅ SM4-SM3 提案配置成功
✅ 连接加载成功: loaded 1 of 1 connections
✅ swanctl --list-conns 显示完整配置
```

---

## 技术细节

### strongSwan 插件加载机制

1. **配置层次**:
   - `charon.plugins.*` - charon 守护进程插件
   - `libstrongswan.plugins.*` - 底层库插件
   
2. **插件搜索路径**:
   ```
   /usr/local/strongswan/lib/ipsec/plugins/libstrongswan-*.so
   ```

3. **GMSM 插件文件**:
   ```
   libstrongswan-gmsm.so
   ```

### 算法注册流程

```
1. charon 启动
   ↓
2. 加载 libstrongswan
   ↓
3. 初始化插件管理器
   ↓
4. 读取 strongswan.conf
   ↓
5. 加载指定插件 (gmsm)
   ↓
6. 调用 gmsm_plugin_create()
   ↓
7. 注册算法:
   - SM2 (签名/加密)
   - SM3 (哈希)
   - SM4 (加密)
   - SM4-GCM (AEAD)
   ↓
8. 算法可用于提案 (proposals)
```

---

## 相关文件

### 已修改文件
- `config/strongswan.conf.gmsm` - 修复配置错误

### 测试脚本
- `test-gmsm-fixed.ps1` - 自动化测试脚本

### Docker 镜像
- `Dockerfile.gmssl` - 无需修改（使用修复后的配置文件）

---

## Git 提交记录

```bash
commit 20b2b65e89...
Author: HankyZhang
Date:   2025-11-12

    修复strongswan.conf配置错误导致的插件加载失败
    
    问题分析:
    - 错误: plugin 'yes': failed to load
    - 原因: load_modular = yes 被误解析为加载名为'yes'的插件
    - 删除: swanctl { load = yes } (swanctl不是插件)
    
    修复内容:
    - 移除 load_modular = yes 配置项
    - 移除 swanctl 插件加载配置
    - 保持 charon.plugins 和 libstrongswan.plugins 正确配置
    - GMSM插件将正确加载并注册SM2/SM3/SM4算法
```

---

## 参考资料

- [strongSwan Configuration File](https://docs.strongswan.org/docs/5.9/config/strongswanConf.html)
- [strongSwan Plugin System](https://docs.strongswan.org/docs/5.9/plugins/plugins.html)
- [GMSM Plugin Implementation](src/libstrongswan/plugins/gmsm/)

---

**更新时间**: 2025-11-12  
**状态**: ✅ 已修复，待验证
