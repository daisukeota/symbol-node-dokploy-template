#!/bin/bash
set -e

echo "=== Symbol Node Shoestring CLI Investigator ==="

echo "Checking top-level shoestring options..."
echo "----------------------------------------"
python3 -m shoestring --help || true
echo "----------------------------------------"

echo "Checking 'setup' sub-command options (if applicable)..."
echo "----------------------------------------"
python3 -m shoestring setup --help || true
echo "----------------------------------------"

# ログを確実に画面に残すため、ここで安全に終了します
exit 0