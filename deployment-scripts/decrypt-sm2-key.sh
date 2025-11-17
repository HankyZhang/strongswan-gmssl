#!/bin/bash
# 从 GmSSL 加密私钥导出未加密版本
# 用于 strongSwan swanctl 加载

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <encrypted_key.pem> <password> <output_plain.pem>"
    exit 1
fi

ENCRYPTED_KEY="$1"
PASSWORD="$2"
OUTPUT_PLAIN="$3"

if [ ! -f "$ENCRYPTED_KEY" ]; then
    echo "Error: Input key file not found: $ENCRYPTED_KEY"
    exit 1
fi

# 使用 Python + GmSSL 库读取加密私钥并重新导出为未加密格式
# 但 GmSSL Python 绑定可能不可用...

# 备选方案: 使用 gmssl 命令生成新的未加密密钥
# 问题: sm2keygen 总是需要密码

# 最终方案: 修改代码使 strongSwan 支持加密私钥读取
#           或在 swanctl 配置中提供密码

echo "GmSSL 3.1.1 的 sm2keygen 不支持生成未加密私钥"
echo "临时解决方案: 修改 strongSwan 代码支持密码读取，或使用外部工具转换"
exit 1
