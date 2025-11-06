# strongSwan VPN 测试自动化脚本
# 用途: 设置 VPN 测试环境

param(
    [string]$RemoteHost = "101.126.148.5",
    [string]$RemoteUser = "root",
    [switch]$UseGMAlgorithm,
    [switch]$SetupServer,
    [switch]$SetupClient
)

$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "strongSwan VPN 测试环境设置" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 创建证书目录
$certDir = Join-Path $PSScriptRoot "vpn-certs"
if (-not (Test-Path $certDir)) {
    New-Item -ItemType Directory -Path $certDir | Out-Null
    Write-Host "[✓] 创建证书目录: $certDir" -ForegroundColor Green
}

# 检查 Docker 镜像
Write-Host "`n[*] 检查 Docker 镜像..." -ForegroundColor Yellow
$image = docker images strongswan-gmssl:3.1.1 --format "{{.Repository}}:{{.Tag}}"
if ($image -eq "strongswan-gmssl:3.1.1") {
    Write-Host "[✓] Docker 镜像已就绪: strongswan-gmssl:3.1.1" -ForegroundColor Green
} else {
    Write-Host "[✗] Docker 镜像不存在，请先构建镜像" -ForegroundColor Red
    exit 1
}

# 功能: 生成标准证书
function Generate-StandardCerts {
    Write-Host "`n[*] 生成标准算法证书..." -ForegroundColor Yellow
    
    # 使用 OpenSSL 生成证书
    $openssl = "openssl"
    
    # 检查 OpenSSL
    try {
        & $openssl version | Out-Null
    } catch {
        Write-Host "[✗] OpenSSL 未安装，请安装 OpenSSL" -ForegroundColor Red
        return $false
    }
    
    # 生成 CA
    & $openssl genrsa -out "$certDir/ca-key.pem" 4096
    & $openssl req -new -x509 -days 3650 -key "$certDir/ca-key.pem" `
        -out "$certDir/ca-cert.pem" `
        -subj "/C=CN/ST=Beijing/L=Beijing/O=VPN Test CA/CN=VPN CA"
    
    # 生成服务端证书
    & $openssl genrsa -out "$certDir/server-key.pem" 2048
    & $openssl req -new -key "$certDir/server-key.pem" `
        -out "$certDir/server-req.pem" `
        -subj "/C=CN/ST=Beijing/L=Beijing/O=VPN Server/CN=$RemoteHost"
    & $openssl x509 -req -days 365 -in "$certDir/server-req.pem" `
        -CA "$certDir/ca-cert.pem" -CAkey "$certDir/ca-key.pem" `
        -CAcreateserial -out "$certDir/server-cert.pem"
    
    # 生成客户端证书
    & $openssl genrsa -out "$certDir/client-key.pem" 2048
    & $openssl req -new -key "$certDir/client-key.pem" `
        -out "$certDir/client-req.pem" `
        -subj "/C=CN/ST=Beijing/L=Beijing/O=VPN Client/CN=vpn-client"
    & $openssl x509 -req -days 365 -in "$certDir/client-req.pem" `
        -CA "$certDir/ca-cert.pem" -CAkey "$certDir/ca-key.pem" `
        -CAcreateserial -out "$certDir/client-cert.pem"
    
    Write-Host "[✓] 标准证书生成完成" -ForegroundColor Green
    return $true
}

# 功能: 生成国密证书
function Generate-GMCerts {
    Write-Host "`n[*] 生成国密算法证书..." -ForegroundColor Yellow
    
    $script = @"
#!/bin/bash
cd /certs

# 生成 CA
gmssl sm2keygen -pass 1234 -out ca-key.pem
gmssl certgen -C CN -ST Beijing -L Beijing -O 'VPN Test CA' \
    -CN 'VPN CA' -days 3650 -key ca-key.pem -pass 1234 -out ca-cert.pem

# 生成服务端证书
gmssl sm2keygen -pass 1234 -out server-key.pem
gmssl reqgen -C CN -ST Beijing -L Beijing -O 'VPN Server' \
    -CN '$RemoteHost' -key server-key.pem -pass 1234 -out server-req.pem
gmssl reqsign -in server-req.pem -days 365 \
    -key ca-key.pem -pass 1234 -cacert ca-cert.pem -out server-cert.pem

# 生成客户端证书
gmssl sm2keygen -pass 1234 -out client-key.pem
gmssl reqgen -C CN -ST Beijing -L Beijing -O 'VPN Client' \
    -CN 'vpn-client' -key client-key.pem -pass 1234 -out client-req.pem
gmssl reqsign -in client-req.pem -days 365 \
    -key ca-key.pem -pass 1234 -cacert ca-cert.pem -out client-cert.pem

echo '证书生成完成'
"@
    
    $script | Out-File -FilePath "$certDir/gen-certs.sh" -Encoding ASCII
    
    docker run --rm -v "${certDir}:/certs" strongswan-gmssl:3.1.1 bash /certs/gen-certs.sh
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[✓] 国密证书生成完成" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[✗] 国密证书生成失败" -ForegroundColor Red
        return $false
    }
}

# 功能: 创建客户端配置
function Create-ClientConfig {
    param([bool]$UseGM)
    
    Write-Host "`n[*] 创建客户端配置..." -ForegroundColor Yellow
    
    if ($UseGM) {
        $config = @"
connections {
    gmsm-client {
        version = 2
        proposals = sm2-sm3-sm4cbc
        remote_addrs = $RemoteHost
        
        local {
            auth = pubkey
            certs = client-cert.pem
            id = vpn-client
        }
        
        remote {
            auth = pubkey
            id = $RemoteHost
        }
        
        children {
            gmsm-tunnel {
                remote_ts = 0.0.0.0/0
                esp_proposals = sm4cbc-sm3
                mode = tunnel
            }
        }
    }
}

secrets {
    private-client {
        file = /certs/client-key.pem
    }
}
"@
    } else {
        $config = @"
connections {
    vpn-client {
        version = 2
        remote_addrs = $RemoteHost
        proposals = aes256-sha256-modp2048
        
        local {
            auth = pubkey
            certs = client-cert.pem
            id = vpn-client
        }
        
        remote {
            auth = pubkey
            id = @$RemoteHost
        }
        
        children {
            tunnel {
                remote_ts = 0.0.0.0/0
                esp_proposals = aes256-sha256
            }
        }
    }
}

secrets {
    private-client {
        file = /certs/client-key.pem
    }
}
"@
    }
    
    $config | Out-File -FilePath "$certDir/swanctl.conf" -Encoding UTF8
    Write-Host "[✓] 客户端配置创建完成: $certDir/swanctl.conf" -ForegroundColor Green
}

# 功能: 创建服务端配置
function Create-ServerConfig {
    param([bool]$UseGM)
    
    Write-Host "`n[*] 创建服务端配置..." -ForegroundColor Yellow
    
    if ($UseGM) {
        $config = @"
connections {
    gmsm-server {
        version = 2
        proposals = sm2-sm3-sm4cbc
        local_addrs = 0.0.0.0
        
        local {
            auth = pubkey
            certs = server-cert.pem
            id = $RemoteHost
        }
        
        remote {
            auth = pubkey
        }
        
        children {
            gmsm-tunnel {
                local_ts = 0.0.0.0/0
                esp_proposals = sm4cbc-sm3
                mode = tunnel
            }
        }
    }
}

secrets {
    private-server {
        file = /certs/server-key.pem
    }
}
"@
    } else {
        $config = @"
config setup
    charondebug="ike 2, knl 2, cfg 2"
    uniqueids=no

conn vpn-server
    type=tunnel
    auto=add
    keyexchange=ikev2
    authby=pubkey
    left=%any
    leftid=@$RemoteHost
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=pubkey
    rightsourceip=10.10.10.0/24
    ike=aes256-sha2_256-modp2048!
    esp=aes256-sha2_256!

: RSA server-key.pem
"@
    }
    
    $config | Out-File -FilePath "$certDir/ipsec.conf" -Encoding UTF8
    Write-Host "[✓] 服务端配置创建完成: $certDir/ipsec.conf" -ForegroundColor Green
}

# 主流程
Write-Host "`n[*] 配置选项:" -ForegroundColor Yellow
Write-Host "  - 远程主机: $RemoteHost" -ForegroundColor White
Write-Host "  - 使用国密: $(if ($UseGMAlgorithm) { '是' } else { '否' })" -ForegroundColor White
Write-Host ""

# 生成证书
if ($UseGMAlgorithm) {
    Generate-GMCerts
} else {
    Generate-StandardCerts
}

# 创建配置
if ($SetupClient) {
    Create-ClientConfig -UseGM $UseGMAlgorithm
}

if ($SetupServer) {
    Create-ServerConfig -UseGM $UseGMAlgorithm
    
    Write-Host "`n[*] 服务端配置文件已创建，需要手动传输到远程服务器:" -ForegroundColor Yellow
    Write-Host "  1. 传输证书: scp $certDir/server-* $certDir/ca-cert.pem ${RemoteUser}@${RemoteHost}:/etc/swanctl/" -ForegroundColor White
    Write-Host "  2. 传输配置: scp $certDir/ipsec.conf ${RemoteUser}@${RemoteHost}:/etc/" -ForegroundColor White
    Write-Host "  3. 重启服务: ssh ${RemoteUser}@${RemoteHost} 'systemctl restart strongswan'" -ForegroundColor White
}

Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "设置完成！" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan

Write-Host "`n下一步操作:" -ForegroundColor Yellow
Write-Host "1. 启动客户端测试:" -ForegroundColor White
Write-Host "   .\start-vpn-client.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. 查看详细测试指南:" -ForegroundColor White
Write-Host "   Get-Content vpn-test-guide.md" -ForegroundColor Cyan
Write-Host ""
