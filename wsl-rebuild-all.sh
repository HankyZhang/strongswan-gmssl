#!/bin/bash
set -e

echo "=== 修复 gmsm 插件并重新编译 ==="

cd /tmp/strongswan-gmsm-final2/strongswan-5.9.6

echo "1. 重新运行 autoreconf 生成 gmsm 的 Makefile"
autoreconf -fi

echo "2. 修复枚举冲突 (KEY_SM2=6, KEY_BLISS应该=7)"
sed -i 's/KEY_BLISS = 6,/KEY_BLISS = 7,/' src/libstrongswan/credentials/keys/public_key.h

echo "3. 修复 public_key.c 中的 key_type_names ENUM"
cat > /tmp/fix_key_type_names.py << 'PY'
import re

with open('src/libstrongswan/credentials/keys/public_key.c', 'r') as f:
    content = f.read()

# 替换 key_type_names ENUM
old_enum = r'ENUM\(key_type_names[^;]+\);'
new_enum = '''ENUM(key_type_names, KEY_ANY, KEY_BLISS,
\t"ANY",
\t"RSA",
\t"ECDSA",
\t"DSA",
\t"ED25519",
\t"ED448",
\t"SM2",
\t"BLISS"
);'''

content = re.sub(old_enum, new_enum, content, count=1)

with open('src/libstrongswan/credentials/keys/public_key.c', 'w') as f:
    f.write(content)

print("✓ key_type_names 已修复")
PY

python3 /tmp/fix_key_type_names.py

echo "4. 验证修改"
echo "=== public_key.h 中的 KEY_BLISS ==="
grep -A 2 "KEY_SM2" src/libstrongswan/credentials/keys/public_key.h

echo ""
echo "=== public_key.c 中的 key_type_names ==="
grep -A 10 "ENUM(key_type_names" src/libstrongswan/credentials/keys/public_key.c

echo ""
echo "5. 重新配置"
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

echo "6. 清理并编译"
make clean
make -j$(nproc) 2>&1 | tee /tmp/make-final.log

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
    tail -50 /tmp/make-final.log
    exit 1
fi
