#!/bin/bash
set -e

echo "=== Symbol Node Shoestring Template Investigator ==="

echo "1. Checking 'init' sub-command help..."
echo "----------------------------------------"
python3 -m shoestring init --help || true
echo "----------------------------------------"

echo "2. Attempting to generate default shoestring.ini template..."
# init コマンドを実行してカレントディレクトリにテンプレートを吐き出させます
# 引数にパッケージ（mainnet）の指定が必要な場合を考慮して両方試します
python3 -m shoestring init --package mainnet || python3 -m shoestring init || true

echo "3. Dumping the generated template content..."
echo "----------------------------------------"
if [ -f "shoestring.ini" ]; then
    cat shoestring.ini
else
    echo "shoestring.ini was not generated in the root. Checking files:"
    ls -la
fi
echo "----------------------------------------"

# ログを確実に画面に残すため、ここで安全に終了します
exit 0