#!/usr/bin/env bash

# ===============================
# 指定フォルダ以下のファイルを
# ファイル名 + 内容 で結合出力
# ===============================

set -euo pipefail

TARGET_DIR="${1:-.}"           # 第1引数。省略時はカレント
OUTPUT_FILE="${2:-output.txt}" # 第2引数。省略時は output.txt

# 出力ファイルを初期化
: > "$OUTPUT_FILE"

# find + while で安全に処理（スペース対応）
find "$TARGET_DIR" -type f | while IFS= read -r file; do
    # バイナリっぽいものはスキップ（必要なければ消してOK）
    if ! file "$file" | grep -q text; then
        continue
    fi

    echo "$file" >> "$OUTPUT_FILE"
    echo "----------------------------------------" >> "$OUTPUT_FILE"
    cat "$file" >> "$OUTPUT_FILE"
    echo -e "\n" >> "$OUTPUT_FILE"
done
