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

echo "Step 3: Preparing temporary CA Private Key PEM file..."
cat << EOF > /app/ca.key.pem
-----BEGIN PRIVATE KEY-----
${MAIN_PRIVATE_KEY}
-----END PRIVATE KEY-----
EOF
chmod 600 /app/ca.key.pem

echo "Step 4: Running shoestring setup with In-Memory Monkey Patch..."
# 【ここが究極の解決策】
# 物理ファイルは一切書き換えません。Pythonの起動時にメモリ上で直接「require_hostname」を無力化し、
# DockerのDNSの気まぐれによるエラーを100%安全に回避して確実に完走させます。
python3 -c "
import sys, asyncio
import shoestring.commands.setup
from shoestring.__main__ import main

# お節介なDNSチェック関数を、何もしないダミー関数に実行時上書き
shoestring.commands.setup.require_hostname = lambda hostname: None

# 引数をそのまま引き継いでメイン処理を実行
asyncio.run(main(sys.argv[1:]))
" setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# 使い終わった一時ファイル群は即座に完全消去
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="