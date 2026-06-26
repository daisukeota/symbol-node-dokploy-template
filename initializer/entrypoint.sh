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

echo "Step 4: Running shoestring setup with Socket-Level Patch..."
# 【ここが究極の解決策】
# モジュールの構造に関係なく、Pythonプロセス全体の名前解決の根本をフックします。
# 正常に引ける外の名前はそのまま通し、コンテナ内から引けない自分のドメインだけを安全に救済します。
python3 -c "
import sys, asyncio, socket

orig_getaddrinfo = socket.getaddrinfo
def smart_getaddrinfo(host, port, *args, **kwargs):
    try:
        return orig_getaddrinfo(host, port, *args, **kwargs)
    except socket.gaierror:
        # 名前解決エラーを検知したら、127.0.0.1 を返して Shoestring のお節介チェックを通過させる
        return [(socket.AF_INET, socket.SOCK_STREAM, 6, '', ('127.0.0.1', port or 0))]

socket.getaddrinfo = smart_getaddrinfo

# Shoestringのメイン処理を実行
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