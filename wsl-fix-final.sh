#!/bin/bash
set -e

echo "=== 全面修复所有枚举定义 ==="

cd /tmp/strongswan-gmsm-final2/strongswan-5.9.6

echo "1. 修复 public_key.h 中的枚举值冲突 (KEY_SM2=6, KEY_BLISS 应该是7)"
sed -i 's/KEY_BLISS = 6,/KEY_BLISS = 7,/' src/libstrongswan/credentials/keys/public_key.h

echo "2. 修复 public_key.c 中的 key_type_names"
# 删除错误的定义并用正确的替换
cat > /tmp/new_key_type_names.c << 'EOF'
ENUM(key_type_names, KEY_ANY, KEY_BLISS,
	"ANY",
	"RSA",
	"ECDSA",
	"DSA",
	"ED25519",
	"ED448",
	"SM2",
	"BLISS"
);
EOF

# 找到并替换整个 key_type_names 定义
python3 << 'PYTHON_SCRIPT'
import re

with open('src/libstrongswan/credentials/keys/public_key.c', 'r') as f:
    content = f.read()

# 替换 key_type_names ENUM定义
pattern = r'ENUM\(key_type_names[^)]+\)[\s\S]*?\);'
with open('/tmp/new_key_type_names.c', 'r') as f:
    replacement = f.read().strip()

content = re.sub(pattern, replacement, content, count=1)

with open('src/libstrongswan/credentials/keys/public_key.c', 'w') as f:
    f.write(content)

print("✓ key_type_names 已替换")
PYTHON_SCRIPT

echo "3. 验证修改"
echo "=== public_key.h 中的 KEY_BLISS ==="
grep -A 2 "KEY_SM2" src/libstrongswan/credentials/keys/public_key.h

echo ""
echo "=== public_key.c 中的 key_type_names ==="
grep -A 10 "ENUM(key_type_names" src/libstrongswan/credentials/keys/public_key.c

echo ""
echo "4. 清理并重新配置"
make clean || true

./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --enable-openssl \
    --enable-swanctl \
    --disable-stroke \
    --disable-scepclient \
    --enable-charon \
    --enable-cmd \
    --with-systemdsystemunitdir=/lib/systemd/system \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

echo "5. 开始编译..."
make -j$(nproc) 2>&1 | tee /tmp/make.log

if [ $? -eq 0 ]; then
    echo ""
    echo "✓✓✓ 编译成功! ✓✓✓"
    echo "开始安装..."
    sudo make install
    echo "✓✓✓ 安装完成! ✓✓✓"
else
    echo ""
    echo "✗✗✗ 编译失败 ✗✗✗"
    echo "最后50行错误:"
    tail -50 /tmp/make.log
    exit 1
fi
