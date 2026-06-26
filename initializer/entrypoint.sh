#!/bin/bash
set -e

echo "=== Symbol Node Initialization via Shoestring ==="

# 必須の環境変数チェック
if [ -z "$MAIN_PRIVATE_KEY" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: MAIN_PRIVATE_KEY and DOMAIN_NAME must be provided via environment variables."
    exit 1
fi

echo "Cleaning up target directory for a fresh initialization..."
rm -rf /app/target/* /app/target/.* 2>/dev/null || true

echo "Step 1: Extracting official shoestring.ini template..."
python3 -m shoestring init --package ${SYMBOL_NETWORK:-mainnet} /app/shoestring.ini

echo "Step 2: Injecting configuration lines directly under [node] section..."
sed -i "/^\[node\]/a domain = ${DOMAIN_NAME}\nname = ${NODE_NAME:-MyDokployNode}" /app/shoestring.ini

echo "--- [DEBUG] Verified shoestring.ini Content ---"
cat /app/shoestring.ini
echo "-----------------------------------------------"

echo "Step 3: Preparing temporary CA Private Key PEM file from HEX string..."
# 【ここをアップグレード！】
# 16進数の秘密鍵にEd25519用のPKCS#8プレフィックスを合成し、OpenSSL対応の正規PEMファイルを生成します
python3 -c "
import base64

hex_key = '${MAIN_PRIVATE_KEY}'.strip()
raw_bytes = bytes.fromhex(hex_key)

# Ed25519秘密鍵の標準的なPKCS#8 ASN.1プレフィックス(16バイト)
prefix = bytes.fromhex('302e020100300506032b657004220420')
pkcs8_bytes = prefix + raw_bytes

# 全体をBase64化し、PEMの作法に従って64文字ごとに改行して書き出し
pem_body = base64.b64encode(pkcs8_bytes).decode('utf-8')
pem_lines = [pem_body[i:i+64] for i in range(0, len(pem_body), 64)]

with open('/app/ca.key.pem', 'w') as f:
    f.write('-----BEGIN PRIVATE KEY-----\n')
    for line in pem_lines:
        f.write(line + '\n')
    f.write('-----END PRIVATE KEY-----\n')
"
chmod 600 /app/ca.key.pem

echo "Step 4: Running shoestring setup with Socket-Level Patch..."
# 前回の強力なソケットフックを維持し、DNS制限を完全に封殺した状態で起動します
python3 -c "
import sys, asyncio, socket

orig_getaddrinfo = socket.getaddrinfo
def smart_getaddrinfo(host, port, *args, **kwargs):
    try:
        return orig_getaddrinfo(host, port, *args, **kwargs)
    except socket.gaierror:
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('127.0.0.1', port or 0))]

socket.getaddrinfo = smart_getaddrinfo

from shoestring.__main__ import main
asyncio.run(main(sys.argv[1:]))
" setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# 使い終わった一時ファイル群は即座に完全消去
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="