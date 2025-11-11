# GMSM VPN 测试脚本 - Linux 服务器版本
# 用于在两台 Linux 服务器上测试国密算法 VPN

param(
    [Parameter(Mandatory=$true)]
    [string]$ClientIP,
    
    [string]$ServerIP = "101.126.148.5",
    
    [ValidateSet("standard", "gmsm")]
    [string]$Mode = "standard",
    
    [switch]$Deploy,
    [switch]$Test,
    [switch]$Monitor
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

# 检查 SSH 连接
function Test-SSHConnection {
    param([string]$IP)
    Write-ColorOutput "检查 SSH 连接到 $IP ..." "Yellow"
    $result = ssh -o ConnectTimeout=5 root@$IP "echo 'OK'" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "❌ 无法连接到 $IP" "Red"
        exit 1
    }
    Write-ColorOutput "✅ SSH 连接成功" "Green"
}

# 部署服务器端
function Deploy-Server {
    Write-ColorOutput "`n=== 部署服务器端配置 ===" "Cyan"
    
    # 确保服务器配置目录存在
    ssh root@$ServerIP "mkdir -p /etc/strongswan-docker/swanctl"
    
    # 上传配置
    scp config/swanctl/gmsm-psk-server.conf root@${ServerIP}:/etc/strongswan-docker/swanctl/swanctl.conf
    
    # 检查容器是否运行
    $containerRunning = ssh root@$ServerIP "docker ps | grep strongswan-gmsm | wc -l"
    if ($containerRunning -eq "0") {
        Write-ColorOutput "容器未运行，正在启动..." "Yellow"
        ssh root@$ServerIP "cd /root/strongswan && docker-compose -f docker-compose.gmssl.yml up -d"
        Start-Sleep -Seconds 5
    }
    
    # 加载配置
    ssh root@$ServerIP "docker exec strongswan-gmsm swanctl --load-all"
    
    # 查看连接定义
    Write-ColorOutput "`n服务器端连接配置：" "Green"
    ssh root@$ServerIP "docker exec strongswan-gmsm swanctl --list-conns"
    
    # 检查监听端口
    Write-ColorOutput "`n监听端口状态：" "Green"
    ssh root@$ServerIP "docker exec strongswan-gmsm netstat -uln | grep -E '500|4500'"
}

# 部署客户端
function Deploy-Client {
    Write-ColorOutput "`n=== 部署客户端配置 ===" "Cyan"
    
    # 确保客户端配置目录存在
    ssh root@$ClientIP "mkdir -p /etc/strongswan-docker/swanctl"
    
    # 上传配置
    scp config/swanctl/gmsm-psk-client.conf root@${ClientIP}:/etc/strongswan-docker/swanctl/swanctl.conf
    
    # 检查容器是否运行
    $containerRunning = ssh root@$ClientIP "docker ps | grep strongswan-client | wc -l"
    if ($containerRunning -eq "0") {
        Write-ColorOutput "客户端容器未运行，正在创建..." "Yellow"
        
        # 检查镜像是否存在
        $imageExists = ssh root@$ClientIP "docker images | grep strongswan-gmssl | grep 3.1.1 | wc -l"
        if ($imageExists -eq "0") {
            Write-ColorOutput "镜像不存在，需要先上传镜像！" "Red"
            Write-ColorOutput "请执行以下步骤：" "Yellow"
            Write-ColorOutput "1. docker save strongswan-gmssl:3.1.1 -o strongswan-gmssl.tar" "White"
            Write-ColorOutput "2. scp strongswan-gmssl.tar root@${ClientIP}:/tmp/" "White"
            Write-ColorOutput "3. ssh root@$ClientIP 'docker load -i /tmp/strongswan-gmssl.tar'" "White"
            exit 1
        }
        
        # 运行客户端容器
        ssh root@$ClientIP @"
docker run -d \
  --name strongswan-client \
  --privileged \
  --network host \
  --restart unless-stopped \
  -v /etc/strongswan-docker/swanctl:/etc/swanctl \
  -v /var/log/strongswan-client:/var/log/strongswan \
  -e GMSSL_ENABLED=1 \
  -e TZ=Asia/Shanghai \
  strongswan-gmssl:3.1.1
"@
        Start-Sleep -Seconds 5
    }
    
    # 加载配置
    ssh root@$ClientIP "docker exec strongswan-client swanctl --load-all"
    
    # 查看连接定义
    Write-ColorOutput "`n客户端连接配置：" "Green"
    ssh root@$ClientIP "docker exec strongswan-client swanctl --list-conns"
}

# 测试连接
function Test-Connection {
    Write-ColorOutput "`n=== 发起 VPN 连接 ===" "Cyan"
    
    # 清理旧连接
    Write-ColorOutput "清理旧连接..." "Yellow"
    ssh root@$ClientIP "docker exec strongswan-client swanctl --terminate --ike gmsm-vpn" 2>$null
    Start-Sleep -Seconds 2
    
    # 发起新连接
    Write-ColorOutput "发起新连接..." "Yellow"
    ssh root@$ClientIP "docker exec strongswan-client swanctl --initiate --child gmsm-net"
    
    Start-Sleep -Seconds 3
    
    # 查看连接状态
    Write-ColorOutput "`n=== 客户端连接状态 ===" "Green"
    $clientStatus = ssh root@$ClientIP "docker exec strongswan-client swanctl --list-sas"
    Write-Host $clientStatus
    
    Write-ColorOutput "`n=== 服务器端连接状态 ===" "Green"
    $serverStatus = ssh root@$ServerIP "docker exec strongswan-gmsm swanctl --list-sas"
    Write-Host $serverStatus
    
    # 检查是否建立连接
    if ($clientStatus -match "ESTABLISHED") {
        Write-ColorOutput "`n✅ VPN 连接已建立！" "Green"
        
        # 测试网络连通性
        Write-ColorOutput "`n=== 测试网络连通性 ===" "Cyan"
        Write-ColorOutput "Ping VPN 网关 (10.10.10.1)..." "Yellow"
        ssh root@$ClientIP "docker exec strongswan-client ping -c 4 10.10.10.1"
        
        # 提取使用的算法
        Write-ColorOutput "`n=== 使用的加密算法 ===" "Cyan"
        if ($clientStatus -match "SM4.*SM3") {
            Write-ColorOutput "✅ 使用国密算法：SM4/SM3" "Green"
        } elseif ($clientStatus -match "AES.*SHA") {
            Write-ColorOutput "ℹ️  使用标准算法：AES/SHA" "Yellow"
        }
        
        return $true
    } else {
        Write-ColorOutput "`n❌ VPN 连接未能建立" "Red"
        
        # 查看日志
        Write-ColorOutput "`n=== 客户端日志（最后 20 行）===" "Yellow"
        ssh root@$ClientIP "docker exec strongswan-client tail -n 20 /var/log/strongswan/charon.log"
        
        return $false
    }
}

# 监控日志
function Monitor-Logs {
    Write-ColorOutput "`n=== 实时监控日志 ===" "Cyan"
    Write-ColorOutput "客户端日志窗口（Ctrl+C 退出）" "Yellow"
    
    ssh root@$ClientIP "docker logs -f strongswan-client"
}

# 显示摘要信息
function Show-Summary {
    Write-ColorOutput "`n=== 环境信息摘要 ===" "Cyan"
    
    Write-ColorOutput "`n服务器 ($ServerIP):" "Green"
    ssh root@$ServerIP @"
echo '容器状态：'
docker ps --filter name=strongswan-gmsm --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ''
echo 'GMSM 插件状态：'
docker exec strongswan-gmsm swanctl --stats | grep -i plugin
echo ''
echo '可用算法（GMSM 相关）：'
docker exec strongswan-gmsm swanctl --list-algs | grep -i 'sm\|gm'
"@
    
    Write-ColorOutput "`n客户端 ($ClientIP):" "Green"
    ssh root@$ClientIP @"
echo '容器状态：'
docker ps --filter name=strongswan-client --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ''
echo 'GMSM 插件状态：'
docker exec strongswan-client swanctl --stats | grep -i plugin
"@
}

# 主流程
function Main {
    Write-ColorOutput "==================================" "Cyan"
    Write-ColorOutput "   GMSM VPN 测试工具" "Cyan"
    Write-ColorOutput "==================================" "Cyan"
    Write-ColorOutput "服务器: $ServerIP" "White"
    Write-ColorOutput "客户端: $ClientIP" "White"
    Write-ColorOutput "模式: $Mode" "White"
    Write-ColorOutput "==================================" "Cyan"
    
    # 检查连接
    Test-SSHConnection -IP $ServerIP
    Test-SSHConnection -IP $ClientIP
    
    if ($Deploy) {
        Deploy-Server
        Deploy-Client
        Show-Summary
    }
    
    if ($Test) {
        $success = Test-Connection
        
        if ($success) {
            Write-ColorOutput "`n🎉 测试成功！" "Green"
            Write-ColorOutput "下一步：可以尝试切换到国密算法模式" "Yellow"
            Write-ColorOutput "编辑配置文件，将 proposals 改为：sm4-sm3-modp2048" "Yellow"
        } else {
            Write-ColorOutput "`n请检查日志排查问题" "Red"
        }
    }
    
    if ($Monitor) {
        Monitor-Logs
    }
    
    if (-not $Deploy -and -not $Test -and -not $Monitor) {
        Write-ColorOutput "`n请指定操作：" "Yellow"
        Write-ColorOutput "  -Deploy   : 部署配置到服务器和客户端" "White"
        Write-ColorOutput "  -Test     : 测试 VPN 连接" "White"
        Write-ColorOutput "  -Monitor  : 实时监控日志" "White"
        Write-ColorOutput "`n示例：" "Yellow"
        Write-ColorOutput "  .\test-gmsm-vpn-linux.ps1 -ClientIP 10.0.0.100 -Deploy" "White"
        Write-ColorOutput "  .\test-gmsm-vpn-linux.ps1 -ClientIP 10.0.0.100 -Test" "White"
    }
}

# 执行主流程
try {
    Main
} catch {
    Write-ColorOutput "`n❌ 错误: $_" "Red"
    Write-ColorOutput $_.ScriptStackTrace "Red"
    exit 1
}
