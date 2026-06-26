#!/bin/bash
set -e

echo "=== Symbol Node Initialization via Shoestring ==="

# 必須の環境変数チェック
if [ -z "$MAIN_PRIVATE_KEY" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: MAIN_PRIVATE_KEY and DOMAIN_NAME must be provided via environment variables."
    exit 1
fi

# すでに設定ファイルが存在する場合は再生成をスキップ（2回目以降の通常起動時）
if [ -f "/app/target/resources/config-node.properties" ]; then
    echo "Configuration already exists. Skipping shoestring setup."
    exit 0
fi

echo "Step 1: Extracting official shoestring.ini template..."
# 公式が用意している完全な設定テンプレートを指定パスに出出しします
python3 -m shoestring init --package ${SYMBOL_NETWORK:-mainnet} /app/shoestring.ini

echo "Step 2: Dynamically injecting environment variables into template..."
# sedコマンドを使い、テンプレート内のドメインとノード名を環境変数の値で確実に上書きします
sed -i "s|^domain =.*|domain = ${DOMAIN_NAME}|" /app/shoestring.ini
sed -i "s|^name =.*|name = ${NODE_NAME:-MyDokployNode}|" /app/shoestring.ini

echo "Step 3: Preparing temporary CA Private Key PEM file..."
cat << EOF > /app/ca.key.pem
-----BEGIN PRIVATE KEY-----
${MAIN_PRIVATE_KEY}
-----END PRIVATE KEY-----
EOF
chmod 600 /app/ca.key.pem

echo "Step 4: Running shoestring setup with official template..."
python3 -m shoestring setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# セキュリティのため、使い終わった一時ファイル群は即座に完全消去
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="