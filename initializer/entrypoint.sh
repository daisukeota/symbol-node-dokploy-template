#!/bin/bash
# -e でエラー時に即死させ、-x で実行された行とエラーログをすべてDokployの画面に吐き出させます
set -ex

echo "=== Symbol Node Initialization via Shoestring (Debug Mode) ==="

# 必須の環境変数チェック
if [ -z "$MAIN_PRIVATE_KEY" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: MAIN_PRIVATE_KEY and DOMAIN_NAME must be provided via environment variables."
    exit 1
fi

# すでに設定ファイルが存在する場合は再生成をスキップ
if [ -f "/app/target/resources/config-node.properties" ]; then
    echo "Configuration already exists. Skipping shoestring setup."
    exit 0
fi

echo "Step 1: Extracting official shoestring.ini template..."
python3 -m shoestring init --package ${SYMBOL_NETWORK:-mainnet} /app/shoestring.ini

echo "--- [DEBUG] Original Template Content ---"
cat /app/shoestring.ini
echo "-----------------------------------------"

echo "Step 2: Dynamically injecting environment variables into template..."
sed -i "s|domain =.*|domain = ${DOMAIN_NAME}|g" /app/shoestring.ini
sed -i "s|name =.*|name = ${NODE_NAME:-MyDokployNode}|g" /app/shoestring.ini

echo "--- [DEBUG] Patched Template Content ---"
cat /app/shoestring.ini
echo "-----------------------------------------"

echo "Step 3: Preparing temporary CA Private Key PEM file..."
cat << EOF > /app/ca.key.pem
-----BEGIN PRIVATE KEY-----
${MAIN_PRIVATE_KEY}
-----END PRIVATE KEY-----
EOF
chmod 600 /app/ca.key.pem

echo "Step 4: Running shoestring setup..."
# ここでエラーが起きた場合、Pythonのスタックトレース（生の理由）がログに残ります
python3 -m shoestring setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# デバッグのため、成功時のみファイルを削除するように変更
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="