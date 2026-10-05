#!/bin/bash
# MouseSwitcher — 卸载
#
# 用法：
#   ./uninstall.sh
#
# 退出进程、取消开机启动、删除 ~/Applications/MouseSwitcher.app。
# 不使用 sudo，不修改系统目录。

set -euo pipefail

APP_NAME="MouseSwitcher"
TARGET_APP="$HOME/Applications/$APP_NAME.app"

echo "==> 退出运行中的实例"
pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" 2>/dev/null || true
sleep 1

echo "==> 删除应用"
rm -rf "$TARGET_APP"
rm -rf "$HOME/Applications/$APP_NAME.app"

echo "==> 清理偏好设置"
defaults delete com.local.MouseSwitcher 2>/dev/null || true

echo ""
echo "✅ 卸载完成"
echo "   如需彻底移除开机启动项，请手动检查："
echo "   系统设置 → 通用 → 登录项与扩展 → 登录时打开"
