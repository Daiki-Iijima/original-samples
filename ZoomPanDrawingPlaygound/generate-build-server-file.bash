#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# xcode-build-server 用 buildServer.json 自動生成スクリプト
#
# 仕様:
# - プロジェクト名 / スキーマ名 = カレントディレクトリ名
# - *.xcworkspace があれば優先的に使用
# - なければ *.xcodeproj を使用
# - buildServer.json へのリダイレクトは行わない
#   （空ファイルが先に作られて壊れるのを防ぐ）
# ============================================================

# カレントディレクトリ名を取得
ROOT_DIR="$(pwd)"
NAME="$(basename "$ROOT_DIR")"

# スキーマ名はフォルダ名と同じ
SCHEME="$NAME"

# 出力ファイル名（xcode-build-server が内部で使う）
OUTPUT="buildServer.json"

# 想定される workspace / project 名
WORKSPACE="${NAME}.xcworkspace"
XCODEPROJ="${NAME}.xcodeproj"

USE_MODE=""   # "workspace" or "project"
USE_PATH=""   # 実際に使うパス

# ------------------------------------------------------------
# workspace / project の自動判定
# ------------------------------------------------------------
if [ -d "$WORKSPACE" ]; then
  USE_MODE="workspace"
  USE_PATH="$WORKSPACE"
elif [ -d "$XCODEPROJ" ]; then
  USE_MODE="project"
  USE_PATH="$XCODEPROJ"
else
  # フォルダ名と一致しない場合のフォールバック
  FIRST_WORKSPACE="$(ls -1d ./*.xcworkspace 2>/dev/null | head -n 1 || true)"
  FIRST_PROJECT="$(ls -1d ./*.xcodeproj 2>/dev/null | head -n 1 || true)"

  if [ -n "$FIRST_WORKSPACE" ]; then
    USE_MODE="workspace"
    USE_PATH="${FIRST_WORKSPACE#./}"
  elif [ -n "$FIRST_PROJECT" ]; then
    USE_MODE="project"
    USE_PATH="${FIRST_PROJECT#./}"
  else
    echo "❌ .xcworkspace または .xcodeproj が見つかりません"
    echo "   対象ディレクトリ: $ROOT_DIR"
    exit 1
  fi
fi

echo "▶ buildServer.json を生成します"
echo "  ディレクトリ名 : $NAME"
echo "  スキーマ名     : $SCHEME"
echo "  使用対象       : $USE_MODE ($USE_PATH)"

# ------------------------------------------------------------
# 重要:
# シェルのリダイレクト ( > buildServer.json ) は使用しない
# → 実行前に空ファイルが作られ、xcode-build-server が
#   それを読もうとしてクラッシュするため
# ------------------------------------------------------------
rm -f "$OUTPUT"

# ------------------------------------------------------------
# xcode-build-server 実行
# ------------------------------------------------------------
if [ "$USE_MODE" = "workspace" ]; then
  xcode-build-server config \
    -workspace "$USE_PATH" \
    -scheme "$SCHEME"
else
  xcode-build-server config \
    -project "$USE_PATH" \
    -scheme "$SCHEME"
fi

# ------------------------------------------------------------
# 生成結果の確認
# ------------------------------------------------------------
if [ -s "$OUTPUT" ]; then
  echo "✅ buildServer.json の生成に成功しました"
else
  echo "❌ buildServer.json が生成されていない、または空です"
  echo "   ・スキーマが Shared になっているか確認してください"
  echo "   ・Xcode で一度ビルドできるか確認してください"
  exit 1
fi

