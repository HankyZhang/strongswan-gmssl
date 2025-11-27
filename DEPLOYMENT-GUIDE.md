# StrongSwan GMSM VPN 完整部署文档

## 概述

本文档提供基于Docker的StrongSwan GMSM VPN完整部署指南，采用混合模式架构：IKE层使用国密算法，ESP层使用标准AES算法。

---

## 系统要求

### 主机要求
- **操作系统**: Linux (推荐 Ubuntu 22.04 或 CentOS 7+)
- **Docker**: 版本 20.10 或更高
- **网络**: 开放 UDP 端口 500 和 4500
- **权限**: root 权限或 sudo 权限

### 网络规划
| 角色 | 公网 IP | 内网 IP | VPN 子网 |
|------|---------|---------|----------|
| 服务器 | 182.92.77.234 | 172.24.18.118 | 10.10.10.0/24 |
| 客户端 | 8.140.37.32 | 172.24.18.28 | 10.10.20.0/24 |

---

## 部署步骤

### 1. 准备Docker镜像

```bash
# 加载StrongSwan GMSM镜像
docker load -i strongswan-gmssl.tar
# 或构建镜像
docker build -t strongswan-gmssl:latest .
```

### 2. 服务器配置

创建服务器配置文件 `swanctl-server.conf`：

```bash
connections {
    gmsm-vpn {
        version = 2
        proposals = sm4gcm16-prfsm3-modp2048
        local_addrs = 172.24.18.118
        remote_addrs = %any
        local {
            auth = psk
            id = 172.24.18.118
        }
        remote {
            auth = psk
            id = %any
        }
        children {
            gmsm-tunnel {
                local_ts = 10.10.10.0/24
                remote_ts = 10.10.20.0/24
                esp_proposals = aes256gcm16-modp2048
                start_action = trap
            }
        }
    }
}

secrets {
    ike-any {
        id = 172.24.18.118
        secret = "GMSMTest2025!"
    }
}
```

### 3. 客户端配置

创建客户端配置文件 `swanctl-client.conf`：

```bash
connections {
    gmsm-vpn {
        version = 2
        proposals = sm4gcm16-prfsm3-modp2048
        local_addrs = 172.24.18.28
        remote_addrs = 172.24.18.118
        local {
            auth = psk
            id = 172.24.18.28
        }
        remote {
            auth = psk
            id = 172.24.18.118
        }
        children {
            gmsm-tunnel {
                local_ts = 10.10.20.0/24
                remote_ts = 10.10.10.0/24
                esp_proposals = aes256gcm16-modp2048
                start_action = start
            }
        }
    }
}

secrets {
    ike-any {
        id = 172.24.18.28
        secret = "GMSMTest2025!"
    }
}
```

### 4. 部署服务器

```bash
# 上传配置文件
scp swanctl-server.conf root@182.92.77.234:/root/

# 部署服务器容器
ssh root@182.92.77.234 'docker stop strongswan-server 2>/dev/null; docker rm strongswan-server 2>/dev/null; docker run -d --name strongswan-server --network host --privileged --cap-add=NET_ADMIN -v /root/swanctl-server.conf:/etc/swanctl/swanctl.conf strongswan-gmssl:latest'

# 配置测试IP
ssh root@182.92.77.234 'docker exec strongswan-server ip addr add 10.10.10.100/24 dev eth0 2>/dev/null || true'

# 加载配置
ssh root@182.92.77.234 'docker exec strongswan-server swanctl --load-all'
```

### 5. 部署客户端

```bash
# 上传配置文件
scp swanctl-client.conf root@8.140.37.32:/root/

# 部署客户端容器
ssh root@8.140.37.32 'docker stop strongswan-client 2>/dev/null; docker rm strongswan-client 2>/dev/null; docker run -d --name strongswan-client --network host --privileged --cap-add=NET_ADMIN -v /root/swanctl-client.conf:/etc/swanctl/swanctl.conf strongswan-gmssl:latest'

# 配置测试IP
ssh root@8.140.37.32 'docker exec strongswan-client ip addr add 10.10.20.100/24 dev eth0 2>/dev/null || true'

# 加载配置
ssh root@8.140.37.32 'docker exec strongswan-client swanctl --load-all'
```

---

## 验证连接

### 1. 检查配置加载

```bash
# 服务器端
ssh root@182.92.77.234 'docker exec strongswan-server swanctl --list-conns'

# 客户端
ssh root@8.140.37.32 'docker exec strongswan-client swanctl --list-conns'
```

### 2. 发起VPN连接

```bash
ssh root@8.140.37.32 'docker exec strongswan-client swanctl --initiate --child gmsm-tunnel'
```

### 3. 检查SA状态

```bash
ssh root@8.140.37.32 'docker exec strongswan-client swanctl --list-sas --raw'
ssh root@182.92.77.234 'docker exec strongswan-server swanctl --list-sas --raw'
```

### 4. 测试连通性

```bash
ssh root@8.140.37.32 'docker exec strongswan-client ping -c 5 10.10.10.100'
```

---

## 故障排除

### 问题1: 配置文件未加载

**症状**: `no connections found, 0 unloaded`

**解决方案**:
```bash
# 检查配置文件
docker exec strongswan-client cat /etc/swanctl/swanctl.conf

# 重新加载配置
docker exec strongswan-client swanctl --load-all
```

### 问题2: ESP提案语法错误

**症状**: `NO_PROPOSAL_CHOSEN` 错误

**解决方案**: 确保ESP提案不包含PRF算法 [1](#34-0) ：
```bash
# 正确语法
esp_proposals = aes256gcm16-modp2048

# 错误语法
esp_proposals = aes256gcm16-prfsm3-modp2048
```

### 问题3: IDr载荷缺失

**症状**: `IDr payload missing` 错误

**解决方案**: 添加明确的ID配置 [2](#34-1) ：
```bash
local {
    auth = psk
    id = 172.24.18.118  # 必须添加
}
```

### 问题4: 重复CHILD_SA错误

**症状**: `existing duplicate` 错误

**解决方案** [3](#34-2) ：
```bash
# 终止现有连接
docker exec strongswan-client swanctl --terminate --ike gmsm-vpn --timeout 5

# 或强制终止
docker exec strongswan-client swanctl --terminate --ike gmsm-vpn --force
```

---

## 配置说明

### 混合模式架构

- **IKE层**: 使用国密算法 `sm4gcm16-prfsm3-modp2048` 满足国密要求 [4](#34-3) 
- **ESP层**: 使用标准AES算法 `aes256gcm16-modp2048` 保证互操作性

### 关键参数

| 参数 | 说明 | 示例值 |
|------|------|--------|
| `version` | IKE版本 | `2` (IKEv2) |
| `proposals` | IKE加密提案 | `sm4gcm16-prfsm3-modp2048` |
| `esp_proposals` | ESP加密提案 | `aes256gcm16-modp2048` |
| `start_action` | 启动动作 | `trap`(服务器)/`start`(客户端) |

### 常用命令

```bash
# 查看VPN状态
docker exec strongswan-client swanctl --list-sas

# 发起连接
docker exec strongswan-client swanctl --initiate --child gmsm-tunnel

# 终止连接
docker exec strongswan-client swanctl --terminate --ike gmsm-vpn

# 重新加载配置
docker exec strongswan-client swanctl --load-all

# 查看连接配置
docker exec strongswan-client swanctl --list-conns
```

---

## 预期结果

成功部署后应显示：

### IKE SA状态
- `state=ESTABLISHED`
- `encr-alg=SM4_GCM_16`
- `prf-alg=PRF_HMAC_SM3`

### CHILD SA状态
- `state=INSTALLED`
- `encr-alg=AES_GCM_16`

### 网络测试
- Ping测试: 0% 丢包率
- 流量通过VPN隧道传输

---

## Notes

- 目录警告（缺少x509ocsp等）可安全忽略 [5](#34-4) 
- 每次修改配置后必须重新部署容器
- 配置文件路径: `/etc/swanctl/swanctl.conf` [6](#34-5) 
- 成功的GMSM VPN应同时使用SM4_GCM_16和PRF_HMAC_SM3算法

---

**文档版本**: 2.0  
**最后更新**: 2025-11-27  
**状态**: 已验证可用

### Citations
