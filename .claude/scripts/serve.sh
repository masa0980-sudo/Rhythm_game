#!/usr/bin/env bash
# ローカルでこのリポジトリ(index.html)を配信するだけのヘルパー。
# ビルド不要な単一HTML構成なので、静的サーバーを立てるだけで動作確認できる。
#
# 使い方: .claude/scripts/serve.sh [port]  (デフォルト 8934)
set -euo pipefail

PORT="${1:-8934}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT"
python3 -m http.server "$PORT"
