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

echo "Preparing temporary CA Private Key PEM file..."
# メイン秘密鍵を、shoestringが要求するヘッダー付きの正確なPEM形式ファイルとして一時出力
cat << EOF > /app/ca.key.pem
-----BEGIN PRIVATE KEY-----
${MAIN_PRIVATE_KEY}
-----END PRIVATE KEY-----
EOF
chmod 600 /app/ca.key.pem

echo "Dynamically generating shoestring.ini..."
# 公式仕様に準拠したクリーンな設定ファイルを生成
cat << EOF > /app/shoestring.ini
[network]
type = ${SYMBOL_NETWORK:-mainnet}

[node]
name = ${NODE_NAME:-MyDokployNode}
domain = ${DOMAIN_NAME}
EOF

echo "Running shoestring setup with correct CLI options..."
# ヘルプに従い、正しいオプション（--config, --ca-key-path, --directory, --package）で実行
python3 -m shoestring setup \
  --config /app/shoestring.ini \
  --ca-key-path /app/ca.key.pem \
  --directory /app/target \
  --package ${SYMBOL_NETWORK:-mainnet}

# セキュリティのため、使い終わった一時PEMファイルは即座に削除
rm -f /app/ca.key.pem

echo "Initialization successfully completed!"