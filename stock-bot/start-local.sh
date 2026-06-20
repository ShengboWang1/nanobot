#!/bin/bash
# 本地启动股票助手（无需 Docker）
# 用法：./start-local.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/.env" ]; then
  export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
else
  echo "错误：找不到 .env 文件"
  exit 1
fi

export NANOBOT_WORKSPACE="$SCRIPT_DIR/workspace"

if ! python3 -c "import pandas, requests, openpyxl" 2>/dev/null; then
  echo "安装 mx-skill 依赖..."
  pip install pandas requests openpyxl -q
fi

echo "启动股票助手  →  http://localhost:8766"
nanobot gateway --config "$SCRIPT_DIR/config.json"
