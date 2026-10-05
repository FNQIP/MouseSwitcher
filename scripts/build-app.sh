#!/bin/bash
# MouseSwitcher — 构建 App Bundle
#
# 用法：
#   ./scripts/build-app.sh                 # 构建 arm64 + x86_64 通用二进制
#   ./scripts/build-app.sh --native        # 只构建本机架构（自用时更快）
#   ./scripts/build-app.sh --version 1.2.3 # 指定版本号写入 Info.plist
#
# 也可通过环境变量指定版本：MS_VERSION=1.2.3 ./scripts/build-app.sh
#
# 产出：
#   build/MouseSwitcher.app
#
# 只依赖 Swift Package Manager + Command Line Tools，不需要 Xcode，
# 不需要 Apple Developer 账号（签名用本地 ad-hoc）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MouseSwitcher"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

BUILD_UNIVERSAL=1
VERSION="${MS_VERSION:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --native)  BUILD_UNIVERSAL=0; shift ;;
        --version) VERSION="${2:-}"; shift 2 ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "未知参数：$1"; exit 1 ;;
    esac
done

echo "==> [1/7] 检查 Swift 工具链"
if ! command -v swift >/dev/null 2>&1; then
    echo "❌ 未找到 swift。请先安装 Command Line Tools：xcode-select --install"
    exit 1
fi
echo "    $(swift --version 2>&1 | head -1)"

echo "==> [2/7] 清理旧的 App Bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# 每个架构用独立的 scratch path，避免产物互相覆盖。
# 注意：本机（Command Line Tools 环境）下 `swift build --arch arm64 --arch x86_64`
# 会报 "xcbuild executable ... does not exist"，因为多架构同时构建依赖 XCBuild
# 框架，而它只随完整 Xcode 提供。所以这里分两次构建再用 lipo 合并。
build_arch() {
    local arch="$1"
    swift build -c release --disable-sandbox \
        --arch "$arch" --scratch-path ".build-$arch" 2>&1 | tail -5
    swift build -c release --disable-sandbox \
        --arch "$arch" --scratch-path ".build-$arch" --show-bin-path
}

if [[ "$BUILD_UNIVERSAL" == "1" ]]; then
    echo "==> [3/7] swift build -c release（arm64 + x86_64 通用二进制）"
    if command -v lipo >/dev/null 2>&1; then
        ARM64_BIN="$(build_arch arm64 | tail -1)/$APP_NAME"
        X86_BIN="$(build_arch x86_64 | tail -1)/$APP_NAME"
    else
        echo "⚠️  缺少 lipo，退化为仅本机架构"
        BUILD_UNIVERSAL=0
    fi

    if [[ "$BUILD_UNIVERSAL" == "1" \
       && -f "$ARM64_BIN" && -f "$X86_BIN" ]]; then
        BIN_PATH="$BUILD_DIR/$APP_NAME.universal"
        lipo -create -output "$BIN_PATH" "$ARM64_BIN" "$X86_BIN"
        echo "    已合并：$(lipo -info "$BIN_PATH" | sed 's/.*are: //')"
    else
        BUILD_UNIVERSAL=0
    fi
fi

if [[ "$BUILD_UNIVERSAL" != "1" ]]; then
    echo "==> [3/7] swift build -c release（仅本机架构）"
    swift build -c release --disable-sandbox 2>&1 | tail -5
    BIN_PATH="$(swift build -c release --disable-sandbox --show-bin-path)/$APP_NAME"
fi

if [[ ! -f "$BIN_PATH" ]]; then
    echo "❌ 构建失败：找不到可执行文件 $BIN_PATH"
    exit 1
fi
echo "    可执行文件：$BIN_PATH"

echo "==> [4/7] 复制可执行文件与 Info.plist"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$PROJECT_DIR/Info.plist" "$CONTENTS/Info.plist"

# 版本号以 Git Tag 为准（发布文档 §19）。CI 从 tag 里剥掉前缀 v 后传进来，
# 避免在多个地方手工维护版本号。
if [[ -n "$VERSION" ]]; then
    echo "    写入版本号 $VERSION"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist"
fi

echo "==> [5/7] 准备图标与 Resources"
ICNS="$PROJECT_DIR/Resources/$APP_NAME.icns"
if [[ ! -f "$ICNS" ]]; then
    echo "    未找到 $APP_NAME.icns，正在生成…"
    mkdir -p "$BUILD_DIR"
    swiftc -O -sdk "$(xcrun --show-sdk-path 2>/dev/null || echo /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk)" \
        "$PROJECT_DIR/Tools/make-icon.swift" -o "$BUILD_DIR/make-icon"
    "$BUILD_DIR/make-icon"
    iconutil -c icns "$BUILD_DIR/$APP_NAME.iconset" -o "$ICNS"
fi
cp "$ICNS" "$RESOURCES_DIR/$APP_NAME.icns"

if [[ -d "$PROJECT_DIR/Resources/Assets" ]]; then
    mkdir -p "$RESOURCES_DIR/Assets"
    cp -R "$PROJECT_DIR/Resources/Assets/." "$RESOURCES_DIR/Assets/" 2>/dev/null || true
fi
# 保留 PkgInfo，让 Finder 正确识别为 Application Bundle
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> [6/7] ad-hoc 签名（不需要 Apple 证书）"
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" 2>/dev/null \
        && echo "    已签名（ad-hoc）" \
        || echo "    ⚠️  签名失败（不影响本地运行）"
else
    echo "    ⚠️  未找到 codesign，跳过签名"
fi

echo "==> [7/7] 校验（发布文档 §21：不通过就 exit 1）"
[[ -d "$APP_DIR" ]] || { echo "❌ App Bundle 不存在"; exit 1; }
[[ -f "$MACOS_DIR/$APP_NAME" ]] || { echo "❌ 可执行文件不存在"; exit 1; }
plutil -lint "$CONTENTS/Info.plist" >/dev/null || { echo "❌ Info.plist 非法"; exit 1; }
# LSUIElement 必须为 true（发布文档 §10）
[[ "$(plutil -extract LSUIElement raw "$CONTENTS/Info.plist")" == "true" ]] \
    || { echo "❌ LSUIElement 不是 true"; exit 1; }

ARCH_INFO="$(file "$MACOS_DIR/$APP_NAME")"
echo "    $ARCH_INFO"
if [[ "$BUILD_UNIVERSAL" == "1" ]]; then
    grep -q "x86_64" <<<"$ARCH_INFO" || { echo "❌ 缺少 x86_64"; exit 1; }
    grep -q "arm64"   <<<"$ARCH_INFO" || { echo "❌ 缺少 arm64"; exit 1; }
fi
echo "    Info.plist 校验通过，LSUIElement=true"
echo "    版本：$(plutil -extract CFBundleShortVersionString raw "$CONTENTS/Info.plist")"

echo ""
echo "✅ 构建完成：$APP_DIR"
echo "   运行：open \"$APP_DIR\""
