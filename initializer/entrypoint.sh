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

echo "Dynamically generating shoestring.ini from environment variables..."

# 環境変数からshoestring用の自動生成用インプットを作成
cat << EOF > /app/shoestring.ini
[network]
type = ${SYMBOL_NETWORK}

[node]
name = ${NODE_NAME}
domain = ${DOMAIN_NAME}

[keys]
main = ${MAIN_PRIVATE_KEY}
vrf = ${VRF_PRIVATE_KEY}
remote = ${REMOTE_PRIVATE_KEY}
voting = ${VOTING_PRIVATE_KEY}
EOF

echo "Running symbol-shoestring to generate node configurations..."
# 成果物を共有ボリュームである /app/target に一気に出力
symbol-shoestring setup --config /app/shoestring.ini --output /app/target

echo "Initialization successfully completed!"