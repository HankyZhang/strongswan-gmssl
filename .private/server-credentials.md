# 阿里云服务器连接信息（私密）

**⚠️ 注意：此文件包含敏感信息，请勿上传到公共仓库！**

---

## 服务器信息

| 项目 | 信息 |
|------|------|
| **IP 地址** | 101.126.148.5 |
| **用户名** | root |
| **密码** | sitech#18%U |
| **操作系统** | CentOS 7 |
| **SSH 端口** | 22 |

## SSH 连接命令

### Windows PowerShell
```powershell
ssh root@101.126.148.5
# 输入密码: sitech#18%U
```

### 使用 SCP 传输文件
```powershell
# 上传文件
scp 本地文件 root@101.126.148.5:/远程路径

# 下载文件
scp root@101.126.148.5:/远程文件 本地路径
```

## 快捷脚本

### 连接服务器
```powershell
# 保存为 connect-server.ps1
$password = ConvertTo-SecureString "sitech#18%U" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("root", $password)

# 注意：ssh 命令不支持 PSCredential，仍需手动输入密码
ssh root@101.126.148.5
```

### 配置 SSH 免密登录（推荐）

**步骤 1**: 生成 SSH 密钥对（如果没有）
```powershell
ssh-keygen -t rsa -b 4096
# 默认保存在 C:\Users\你的用户名\.ssh\id_rsa
```

**步骤 2**: 复制公钥到服务器
```powershell
# 方法 A: 使用 ssh-copy-id（如果可用）
ssh-copy-id root@101.126.148.5

# 方法 B: 手动复制
# 1. 查看本地公钥
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub

# 2. 登录服务器
ssh root@101.126.148.5
# 输入密码: sitech#18%U

# 3. 在服务器上添加公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "你的公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
exit
```

**步骤 3**: 测试免密登录
```powershell
ssh root@101.126.148.5
# 应该无需输入密码直接登录
```

## 安全建议

### 1. 修改 SSH 密码
```bash
ssh root@101.126.148.5
passwd
# 输入新密码两次
```

### 2. 禁用密码登录（配置密钥后）
```bash
ssh root@101.126.148.5
vi /etc/ssh/sshd_config

# 修改以下配置:
PasswordAuthentication no
PubkeyAuthentication yes

# 重启 SSH 服务
systemctl restart sshd
```

### 3. 配置防火墙（已确认 firewalld 已禁用）
```bash
# 当前状态：inactive（已禁用）
# 如需启用，添加必要规则后再启动
```

## 阿里云控制台

- **登录地址**: https://ecs.console.aliyun.com
- **找到实例**: 搜索 IP `101.126.148.5`
- **重置密码**: 实例详情 → 重置实例密码
- **重启实例**: 实例详情 → 重启

## Docker 容器信息

| 容器名 | 镜像 | 状态 | 端口 |
|--------|------|------|------|
| strongswan-gmsm | strongswan-gmssl:3.1.1 | Running (healthy) | UDP 500, 4500 |

### 容器操作命令
```bash
# 查看容器
ssh root@101.126.148.5 "docker ps"

# 查看日志
ssh root@101.126.148.5 "docker logs strongswan-gmsm"

# 进入容器
ssh root@101.126.148.5 "docker exec -it strongswan-gmsm bash"

# 重启容器
ssh root@101.126.148.5 "docker restart strongswan-gmsm"
```

## VPN 配置文件位置

| 文件 | 路径 |
|------|------|
| strongSwan 配置 | /etc/strongswan-docker/strongswan.conf |
| Swanctl 配置 | /etc/strongswan-docker/swanctl/swanctl.conf |
| 证书目录 | /etc/strongswan-docker/swanctl/x509/ |
| 私钥目录 | /etc/strongswan-docker/swanctl/private/ |
| CA 证书 | /etc/strongswan-docker/swanctl/x509ca/ |

## 常用操作

### 查看 VPN 状态
```bash
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-sas"
```

### 查看连接配置
```bash
ssh root@101.126.148.5 "docker exec strongswan-gmsm swanctl --list-conns"
```

### 上传新配置
```powershell
scp config/swanctl/新配置.conf root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf
ssh root@101.126.148.5 "docker restart strongswan-gmsm"
```

### 备份配置
```powershell
# 下载当前配置到本地
scp root@101.126.148.5:/etc/strongswan-docker/swanctl/swanctl.conf ./backup-$(Get-Date -Format 'yyyyMMdd').conf
```

---

**创建时间**: 2025-11-11  
**最后更新**: 2025-11-11  

**⚠️ 重要提醒**:
1. 此文件包含敏感信息，请妥善保管
2. 不要提交到 Git 仓库（已在 .gitignore 中）
3. 建议配置 SSH 密钥登录后禁用密码登录
4. 定期修改密码以提高安全性
