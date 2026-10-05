#!/bin/bash
# MouseSwitcher — 运行脚本
#
# 用法：
#   ./run-app.sh            # 不存在则先构建，再启动
#   ./run-app.sh --rebuild  # 强制重新构建后启动

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MouseSwitcher"
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"

FORCE_REBUILD=0
if [[ "${1:-}" == "--rebuild" || "${1:-}" == "-r" ]]; then
    FORCE_REBUILD=1
fi

if [[ $FORCE_REBUILD -eq 1 || ! -d "$APP_DIR" ]]; then
    echo "==> 构建 App…"
    ./scripts/build-app.sh
fi

# 已经在运行就先退出旧实例，避免菜单栏出现两个图标
if pgrep -f "$APP_DIR/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
    echo "==> 退出正在运行的旧实例…"
    pkill -f "$APP_DIR/Contents/MacOS/$APP_NAME" || true
    sleep 1
fi

echo "==> 启动 $APP_NAME"
open "$APP_DIR"

sleep 2

echo "==> 运行状态"
if pgrep -f "$APP_DIR/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
    PID=$(pgrep -f "$APP_DIR/Contents/MacOS/$APP_NAME" | head -1)
    echo "✅ $APP_NAME 正在运行 (PID: $PID)"
    echo "   菜单栏顶部应出现「🖥 MouseSwitcher」"
else
    echo "❌ 进程未启动，请检查日志："
    echo "   \"$APP_DIR/Contents/MacOS/$APP_NAME\""
fi
