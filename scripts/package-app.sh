#!/bin/bash
# MouseSwitcher — 把 App 打包成分发用的 ZIP / DMG
#
# 用法：
#   ./scripts/package-app.sh                 # 产出 dist/MouseSwitcher-macos-universal.zip
#   ./scripts/package-app.sh --dmg           # 额外产出 dist/MouseSwitcher-macos-universal.dmg
#   ./scripts/package-app.sh --version 1.0.0 # 覆盖文件名里的版本号
#
# 说明：
#   ZIP 内部直接包含 MouseSwitcher.app（不是再套一层目录），
#   用户解压后就能直接拖进 Applications（发布文档 §13）。
#   使用 `ditto -c -k --keepParent` 而非普通 zip：前者会保留
#   macOS 的扩展属性与 resource fork，更接近 Finder「压缩」的结果。
#
#   DMG 是额外产物，失败不会导致整体失败（发布文档 §35）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MouseSwitcher"
SOURCE_APP="$PROJECT_DIR/build/$APP_NAME.app"
DIST_DIR="$PROJECT_DIR/dist"
WANT_DMG=0
VERSION="${MS_VERSION:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dmg)     WANT_DMG=1; shift ;;
        --version) VERSION="${2:-}"; shift 2 ;;
        *) echo "未知参数：$1"; exit 1 ;;
    esac
done

[[ -d "$SOURCE_APP" ]] || { echo "❌ 找不到 ${SOURCE_APP}，请先运行 ./scripts/build-app.sh"; exit 1; }

# 架构决定文件名后缀（发布文档 §13 / §16）
if file "$SOURCE_APP/Contents/MacOS/$APP_NAME" | grep -q "universal binary"; then
    ARCH_TAG="universal"
elif file "$SOURCE_APP/Contents/MacOS/$APP_NAME" | grep -q "arm64"; then
    ARCH_TAG="arm64"
else
    ARCH_TAG="x86_64"
fi

[[ -n "$VERSION" ]] || VERSION="$(plutil -extract CFBundleShortVersionString raw "$SOURCE_APP/Contents/Info.plist")"

mkdir -p "$DIST_DIR"
ZIP_NAME="$APP_NAME-macos-$ARCH_TAG.zip"
DMG_NAME="$APP_NAME-macos-$ARCH_TAG.dmg"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
DMG_PATH="$DIST_DIR/$DMG_NAME"
rm -f "$ZIP_PATH" "$DMG_PATH"

echo "==> 打包 ZIP（架构：${ARCH_TAG}，版本：${VERSION}）"
ditto -c -k --keepParent "$SOURCE_APP" "$ZIP_PATH"

# 校验 ZIP 顶层结构必须是 MouseSwitcher.app/...（发布文档 §13）
TOPLEVEL="$(unzip -Z1 "$ZIP_PATH" | head -1)"
[[ "$TOPLEVEL" == "$APP_NAME.app/" ]] \
    || { echo "❌ ZIP 顶层结构异常：${TOPLEVEL}（应为 $APP_NAME.app/）"; exit 1; }

if [[ "$WANT_DMG" == "1" ]]; then
    echo "==> 打包 DMG（额外产物，失败不影响 ZIP）"
    if STAGE="$(mktemp -d)" \
        && cp -R "$SOURCE_APP" "$STAGE/" \
        && hdiutil create -quiet -srcfolder "$STAGE" -volname "$APP_NAME $VERSION" \
               -fs HFS+ -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"; then
        echo "    ✅ $DMG_PATH"
    else
        echo "    ⚠️  DMG 打包失败，跳过（ZIP 不受影响）"
        rm -f "$DMG_PATH"
    fi
    [[ -n "${STAGE:-}" && -d "${STAGE:-}" ]] && rm -rf "$STAGE"
fi

echo ""
echo "✅ 打包完成"
ls -lh "$ZIP_PATH"
[[ -f "$DMG_PATH" ]] && ls -lh "$DMG_PATH"
echo "   ZIP 顶层：$TOPLEVEL"
