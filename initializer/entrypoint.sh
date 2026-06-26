#!/bin/bash
set -e

echo "=== Symbol Node Initialization via Shoestring ==="

# 必須の環境変数チェック
if [ -z "$MAIN_PRIVATE_KEY" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: MAIN_PRIVATE_KEY and DOMAIN_NAME must be provided via environment variables."
    exit 1
fi

# 完全にセットアップが完了している場合の判定用マーカー
DONE_MARKER="/app/target/userconfig/resources/config-node.properties"

if [ -f "$DONE_MARKER" ]; then
    echo "=== Configuration already exists and is valid. Skipping shoestring setup. ==="
    exit 0
fi

# もしセットアップ未完了なのにディレクトリだけが存在する場合は、衝突を避けるため一度削除
if [ -d "/app/target/userconfig" ]; then
    echo "Found incomplete userconfig directory. Cleaning up for a fresh setup..."
    rm -rf /app/target/userconfig
fi

echo "Step 1: Extracting official shoestring.ini template..."
python3 -m shoestring init --package ${SYMBOL_NETWORK:-mainnet} /app/shoestring.ini

echo "Step 2: Dynamically injecting node configuration into template..."
# [node] セクションの直後に、domain と name の設定行を確実に「挿入」します（networkセクションを壊しません）
sed -i "/^\[node\]/a domain = ${DOMAIN_NAME}\nname = ${NODE_NAME:-MyDokployNode}" /app/shoestring.ini

echo "Step 3: Preparing temporary CA Private Key PEM file..."
cat << EOF > /app/ca.key.pem
-----BEGIN PRIVATE KEY-----
${MAIN_PRIVATE_KEY}
-----END PRIVATE KEY-----
EOF
chmod 600 /app/ca.key.pem

echo "Step 4: Running shoestring setup..."
python3 -m shoestring setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# セキュリティのため、使い終わった一時ファイル群は即座に完全消去
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="