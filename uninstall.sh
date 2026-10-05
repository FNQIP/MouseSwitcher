#!/bin/bash
# MouseSwitcher — 卸载
#
# 用法：
#   ./uninstall.sh
#
# 会做这些事：
#   1. 退出正在运行的实例
#   2. 取消开机启动（SMAppService 登录项）— 必须在删 App 之前做
#   3. 删除 /Applications 与 ~/Applications 两处的 MouseSwitcher.app
#   4. 删除偏好设置（UserDefaults）
#   5. 清除辅助功能授权记录（TCC）
#
# 不使用 sudo，不修改系统目录（/Applications 若不可写则只清用户目录）。

set -uo pipefail

APP_NAME="MouseSwitcher"
BUNDLE_ID="com.local.MouseSwitcher"
PROC_PATTERN="$APP_NAME.app/Contents/MacOS/$APP_NAME"

FOUND=0

echo "==> 退出运行中的实例"
pkill -f "$PROC_PATTERN" 2>/dev/null && sleep 1 || echo "    （没有正在运行的实例）"

# ---------------------------------------------------------------------------
# 1. 取消开机启动
# ---------------------------------------------------------------------------
# SMAppService 的登录项必须在 App 还存在时才能 unregister，
# 所以这一步一定要放在删除 App 之前。
unregister_login() {
    local app="$1"
    local bin="$app/Contents/MacOS/$APP_NAME"
    [[ -x "$bin" ]] || return 1
    # 旧版二进制不认识 --unregister-login，会当成正常启动。先确认支持。
    strings "$bin" 2>/dev/null | grep -q -- "--unregister-login" || return 1
    "$bin" --unregister-login >/dev/null 2>&1
}

echo "==> 取消开机启动"
DID_UNREGISTER=0
for app in "/Applications/$APP_NAME.app" "$HOME/Applications/$APP_NAME.app"; do
    if [[ -d "$app" ]] && unregister_login "$app"; then
        echo "    ✓ 已移除登录项（${app}）"
        DID_UNREGISTER=1
        break
    fi
done
if [[ "$DID_UNREGISTER" == "0" ]]; then
    echo "    ⚠️  无法自动移除（App 已不存在，或是未支持该参数的旧版本）"
    echo "       请手动检查：系统设置 → 通用 → 登录项与扩展 → 登录时打开"
fi

# ---------------------------------------------------------------------------
# 2. 删除应用
# ---------------------------------------------------------------------------
echo "==> 删除应用"
for dir in "/Applications" "$HOME/Applications"; do
    app="$dir/$APP_NAME.app"
    if [[ -d "$app" ]]; then
        if rm -rf "$app" 2>/dev/null; then
            echo "    ✓ 已删除 $app"
            FOUND=1
        else
            echo "    ⚠️  删除失败（权限不足）：$app"
            echo "       可手动执行：rm -rf \"$app\""
        fi
    fi
done
[[ "$FOUND" == "1" ]] || echo "    （两处都没有找到 ${APP_NAME}.app）"

# ---------------------------------------------------------------------------
# 3. 清理偏好设置
# ---------------------------------------------------------------------------
echo "==> 清理偏好设置"
if defaults read "$BUNDLE_ID" >/dev/null 2>&1; then
    defaults delete "$BUNDLE_ID" 2>/dev/null && echo "    ✓ 已删除 $BUNDLE_ID 的设置" || true
    rm -f "$HOME/Library/Preferences/${BUNDLE_ID}.plist" 2>/dev/null || true
else
    echo "    （没有找到相关设置）"
fi

# ---------------------------------------------------------------------------
# 4. 清除辅助功能授权记录
# ---------------------------------------------------------------------------
echo "==> 清除辅助功能授权记录"
if command -v tccutil >/dev/null 2>&1; then
    tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null \
        && echo "    ✓ 已重置 ${BUNDLE_ID} 的辅助功能授权" \
        || echo "    ⚠️  重置失败或无记录；可在 系统设置 → 隐私与安全性 → 辅助功能 里手动移除"
else
    echo "    ⚠️  本机没有 tccutil，跳过"
fi

# ---------------------------------------------------------------------------
# 收尾
# ---------------------------------------------------------------------------
echo ""
echo "✅ 卸载完成"
echo ""
echo "还剩下的（系统管理，脚本无法代劳）："
echo "   • 系统设置 → 通用 → 登录项与扩展：确认没有 MouseSwitcher"
echo "   • 系统设置 → 隐私与安全性 → 辅助功能：确认列表已清空该条目"
echo "      （以上两项在下次重启系统设置后才会刷新，属正常现象）"
echo ""
echo "验证是否卸干净："
echo "   mdfind \"kMDItemCFBundleIdentifier == '${BUNDLE_ID}'\"    # 应无输出"
echo "   pgrep -fl ${APP_NAME}                                    # 应无输出"
