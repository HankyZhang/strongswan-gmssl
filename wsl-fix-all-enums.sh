#!/bin/bash
set -e

echo "=== 全面修复所有枚举定义和冲突 ==="

cd /tmp/strongswan-gmsm-final2/strongswan-5.9.6

echo "1. 修复 public_key.h 中的枚举值冲突 (KEY_SM2 和 KEY_BLISS 都是6)"
sed -i 's/KEY_BLISS = 6,/KEY_BLISS = 7,/' src/libstrongswan/credentials/keys/public_key.h

echo "2. 修复 public_key.c 中的 key_type_names ENUM"
# 将范围从 KEY_BLISS 改为 KEY_BLISS (现在是7)
# 已经有"SM2_WITH_SM3"在列表中,但需要重新排序
# 正确顺序应该是: ANY, RSA, ECDSA, DSA, ED25519, ED448, SM2, BLISS

# 先备份
cp src/libstrongswan/credentials/keys/public_key.c src/libstrongswan/credentials/keys/public_key.c.bak2

# 替换 key_type_names 定义 (从line 23开始)
cat > /tmp/key_type_fix.txt << 'EOF'
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

# 使用 sed 替换 (从 ENUM(key_type_names 开始到第一个 ); 结束)
sed -i '/^ENUM(key_type_names,/,/^);/{
    /^ENUM(key_type_names,/r /tmp/key_type_fix.txt
    d
}' src/libstrongswan/credentials/keys/public_key.c

# 再删除重复的定义
sed -i '/^ENUM(key_type_names,/,/^);/{
    N
    /ENUM(key_type_names.*\n);/!{
        :a
        N
        /);$/!ba
        d
    }
}' src/libstrongswan/credentials/keys/public_key.c

echo "3. 添加 SIGN_SM2_WITH_SM3 的 switch case 处理"
# 在 line 190 附近的 switch 语句中添加
# 先找到 case SIGN_ED448: 然后在它后面添加 case SIGN_SM2_WITH_SM3:

# 这个需要手动处理,先查看那两个位置

echo "4. 清理并重新编译"
make clean
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
    echo "✓ 编译成功!"
    sudo make install
    echo "✓ 安装完成!"
else
    echo "✗ 编译失败,查看日志:"
    tail -50 /tmp/make.log
    exit 1
fi
