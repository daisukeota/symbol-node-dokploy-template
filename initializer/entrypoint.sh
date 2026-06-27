#!/bin/bash
set -e

echo "=== Symbol Node Initialization via Shoestring ==="

if [ -z "$MAIN_PRIVATE_KEY" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: MAIN_PRIVATE_KEY and DOMAIN_NAME must be provided via environment variables."
    exit 1
fi

rm -rf /app/target
mkdir -p /app/target

echo "Step 1: Extracting official shoestring.ini template..."
python3 -m shoestring init --package ${SYMBOL_NETWORK:-mainnet} /app/shoestring.ini

echo "Step 2: Injecting certification config and preparing overrides.ini..."
sed -i "s|^caCommonName =.*|caCommonName = CA - ${NODE_NAME:-MyDokployNode}|" /app/shoestring.ini
sed -i "s|^nodeCommonName =.*|nodeCommonName = Node - ${NODE_NAME:-MyDokployNode}|" /app/shoestring.ini

# 👇 【ここが重要】friendlyName と host をCatapultのプロパティに確実に届けるため、overrides.ini を動的生成します
cat << EOF > /app/overrides.ini
[node.localnode]
host = ${DOMAIN_NAME}
friendlyName = ${NODE_NAME:-MyDokployNode}
EOF

echo "Step 3: Preparing temporary CA Private Key PEM file from HEX string..."
python3 -c "
import base64
hex_key = '${MAIN_PRIVATE_KEY}'.strip()
raw_bytes = bytes.fromhex(hex_key)
prefix = bytes.fromhex('302e020100300506032b657004220420')
pkcs8_bytes = prefix + raw_bytes
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
  --package ${SYMBOL_NETWORK:-mainnet} \
  --overrides /app/overrides.ini # 👈 【ここが重要】生成したoverridesファイルを引数に追加します

echo "Step 5: Distributing generated files to target volumes with full permissions..."
rm -rf /app/dest_startup/* /app/dest_userconfig/* /app/dest_mongo/* /app/dest_seed/* /app/dest_certificates/* 2>/dev/null || true

cp -a /app/target/startup/. /app/dest_startup/
cp -a /app/target/userconfig/. /app/dest_userconfig/
cp -a /app/target/mongo/. /app/dest_mongo/
cp -a /app/target/seed/. /app/dest_seed/

# Shoestringの証明書格納場所を自動探索して確実に配送する安全装置
if [ -d "/app/target/userconfig/resources/cert" ]; then
    cp -a /app/target/userconfig/resources/cert/. /app/dest_certificates/
elif [ -d "/app/target/certificates" ]; then
    cp -a /app/target/certificates/. /app/dest_certificates/
else
    DETECTED_DIR=$(find /app/target -name "ca.pubkey.pem" -exec dirname {} \; | head -n 1)
    if [ -n "$DETECTED_DIR" ]; then
        cp -a "$DETECTED_DIR"/. /app/dest_certificates/
    else
        echo "ERROR: FAILED TO LOCATE CERTIFICATES"
        exit 1
    fi
fi

chmod -R 777 /app/dest_startup /app/dest_userconfig /app/dest_mongo /app/dest_seed /app/dest_certificates || true
rm -f /app/ca.key.pem /app/shoestring.ini /app/overrides.ini # 🗑️ 一時ファイルのクリーンアップ

echo "=== Initialization successfully completed! ==="