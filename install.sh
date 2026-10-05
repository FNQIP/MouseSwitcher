#!/bin/bash
# MouseSwitcher — 安装脚本
#
# 用法：
#   ./install.sh              # 装到 /Applications（Finder「应用程序」里能看到）
#                             # 若不可写则自动退回到 ~/Applications
#   ./install.sh --user       # 强制装到 ~/Applications（不需要管理员权限）
#   ./install.sh --system     # 强制装到 /Applications（可能需要 sudo）
#
# 说明：
#   访达侧边栏的「应用程序」指向 /Applications，而 ~/Applications 是
#   每个用户私有的目录，访达默认不显示——但启动台会同时收录两者，
#   所以只装在 ~/Applications 时会出现「启动台有、应用程序里没有」。

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MouseSwitcher"
SOURCE_APP="$PROJECT_DIR/build/$APP_NAME.app"

MODE="${1:-auto}"
case "$MODE" in
    --user)   USER_MODE=1 ;;
    --system) USER_MODE=0 ;;
    *)        USER_MODE=1; [[ -w /Applications ]] && USER_MODE=0 ;;
esac

if [[ "$USER_MODE" == "0" ]]; then
    TARGET_DIR="/Applications"
else
    TARGET_DIR="$HOME/Applications"
fi
TARGET_APP="$TARGET_DIR/$APP_NAME.app"

if [[ ! -d "$SOURCE_APP" ]]; then
    echo "==> 未找到已构建的 App，先执行构建…"
    ./scripts/build-app.sh
fi

# /Applications 需要写权限；没有就退回用户目录
if [[ ! -w "$TARGET_DIR" ]]; then
    echo "⚠️  $TARGET_DIR 不可写，改用 $HOME/Applications"
    TARGET_DIR="$HOME/Applications"
    TARGET_APP="$TARGET_DIR/$APP_NAME.app"
fi

echo "==> 准备目录：$TARGET_DIR"
if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
    echo "⚠️  无法创建 ${TARGET_DIR}，改用 $HOME/Applications"
    TARGET_DIR="$HOME/Applications"
    TARGET_APP="$TARGET_DIR/$APP_NAME.app"
    mkdir -p "$TARGET_DIR"
fi

# 如果正在运行，先退出
if pgrep -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
    echo "==> 退出正在运行的实例…"
    pkill -f "$APP_NAME.app/Contents/MacOS/$APP_NAME" || true
    sleep 1
fi

echo "==> 安装到 $TARGET_APP"
rm -rf "$TARGET_APP"
cp -R "$SOURCE_APP" "$TARGET_APP"

# 自己从源码构建不会产生隔离标记；从压缩包/网络解出来的会有，这里顺手清掉，
# 否则首次双击会被 Gatekeeper 拦一道（见 dist.sh 里的说明）。
if xattr -p com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1; then
    echo "==> 清除隔离标记"
    xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
fi

echo ""
echo "✅ 安装完成"
echo "   应用位置：$TARGET_APP"
echo "   启动：open \"$TARGET_APP\""
echo ""
if [[ "$TARGET_DIR" == "/Applications" ]]; then
    echo "   现在访达 → 应用程序 里也能看到它了。"
else
    echo "   提示：这个位置是用户私有目录，访达的「应用程序」看不到。"
    echo "        想让它出现在那儿，请执行：./install.sh --system"
fi
echo "   可在菜单栏菜单勾选「开机启动」，或手动加入"
echo "   系统设置 → 通用 → 登录项。"
