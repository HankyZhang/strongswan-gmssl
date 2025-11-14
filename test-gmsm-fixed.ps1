# ============================================================================
# strongSwan + GmSSL 测试脚本 (修复版)
# 测试 SM4-SM3 算法配置解析
# ============================================================================

$IMAGE_NAME = "strongswan-gmssl:3.1.1-gmsm-fixed"
$CONTAINER_NAME = "test-gmsm-fixed"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  strongSwan + GmSSL 配置测试" -ForegroundColor Yellow
Write-Host "  测试镜像: $IMAGE_NAME" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 启动容器
Write-Host "[1/5] 启动测试容器..." -ForegroundColor Yellow
docker run --rm -d --name $CONTAINER_NAME --privileged $IMAGE_NAME
Start-Sleep -Seconds 3

# 检查配置文件
Write-Host ""
Write-Host "[2/5] 检查 strongswan.conf 配置..." -ForegroundColor Yellow
docker exec $CONTAINER_NAME bash -c "cat /etc/strongswan.conf | head -20"

# 检查 GMSM 插件
Write-Host ""
Write-Host "[3/5] 检查 GMSM 插件..." -ForegroundColor Yellow
docker exec $CONTAINER_NAME bash -c "ls -lh /usr/local/strongswan/lib/ipsec/plugins/ | grep gmsm"

# 写入测试配置
Write-Host ""
Write-Host "[4/5] 创建测试连接配置..." -ForegroundColor Yellow
docker exec $CONTAINER_NAME bash -c "cat > /etc/swanctl/swanctl.conf << 'EOFCONFIG'
connections {
    test-sm4 {
        version = 2
        proposals = sm4-sm3-modp2048
        local_addrs = 0.0.0.0
        local {
            auth = psk
            id = test.local
        }
        remote {
            auth = psk
        }
        children {
            child {
                esp_proposals = sm4-sm3
                local_ts = 0.0.0.0/0
            }
        }
    }
}

secrets {
    ike {
        id = test.local
        secret = test123
    }
}
EOFCONFIG
"

# 测试配置加载
Write-Host ""
Write-Host "[5/5] 测试 SM4-SM3 配置加载..." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
docker exec $CONTAINER_NAME bash -c "swanctl --load-conns"
Write-Host "=========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "查看连接详情..." -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Cyan
docker exec $CONTAINER_NAME bash -c "swanctl --list-conns"
Write-Host "=========================================" -ForegroundColor Cyan

# 清理
Write-Host ""
Write-Host "清理测试容器..." -ForegroundColor Yellow
docker stop $CONTAINER_NAME > $null
docker rm $CONTAINER_NAME > $null 2>&1

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  测试完成" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Green
