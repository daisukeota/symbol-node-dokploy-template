#!/bin/bash
set -e

echo "=== Symbol Node Initialization via Shoestring ==="

# 必須の環境変数チェック
if [ -z "$MAIN_PRIVATE_KEY" ] || [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: MAIN_PRIVATE_KEY and DOMAIN_NAME must be provided via environment variables."
    exit 1
fi

# 前回のゴミや中途半端な生成物を一度確実にクリーンアップ
echo "Cleaning up target directory for a fresh initialization..."
rm -rf /app/target/* /app/target/.* 2>/dev/null || true

echo "Step 1: Extracting official shoestring.ini template..."
python3 -m shoestring init --package ${SYMBOL_NETWORK:-mainnet} /app/shoestring.ini

echo "Step 2: Dynamically injecting node configuration via Python configparser..."
# sedを使わず、Pythonの機能で安全かつ確実に[node]セクションへドメインと名前を注入します
python3 -c "
import configparser
config = configparser.ConfigParser()
config.read('/app/shoestring.ini')
if 'node' not in config:
    config['node'] = {}
config['node']['domain'] = '${DOMAIN_NAME}'
config['node']['name'] = '${NODE_NAME:-MyDokployNode}'
with open('/app/shoestring.ini', 'w') as f:
    config.write(f)
"

echo "Step 3: Preparing temporary CA Private Key PEM file..."
cat << EOF > /app/ca.key.pem
-----BEGIN PRIVATE KEY-----
${MAIN_PRIVATE_KEY}
-----END PRIVATE KEY-----
EOF
chmod 600 /app/ca.key.pem

echo "Step 3.5: Bypassing Shoestring DNS resolution check..."
# コンテナ内の /etc/hosts にドメインを強制登録し、DNS反映前でも名前解決を成功させます
echo "127.0.0.1 ${DOMAIN_NAME}" >> /etc/hosts

echo "Step 4: Running shoestring setup..."
python3 -m shoestring setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# セキュリティのため、使い終わった一時ファイル群は即座に完全消去
rm -f /app/ca.key.pem /app/shoestring.ini

echo "=== Initialization successfully completed! ==="