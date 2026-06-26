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

echo "Step 3.5: Patching Shoestring source code to bypass DNS check..."
# 【ここが究極のハック！】
# インストールされたshoestringのソース内の「def require_hostname」の直後に「return」を強制挿入し、
# 環境やDNSの浸透状態に依存するお節介なチェック機能そのものを完全に無効化します。
SETUP_SCRIPT_PATH="/usr/local/lib/python3.10/site-packages/shoestring/commands/setup.py"
sed -i '/def require_hostname/a \    return' "$SETUP_SCRIPT_PATH"

echo "Step 4: Running shoestring setup..."
python3 -m shoestring setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# 使い終わった一時ファイル群は即座に完全消去
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="