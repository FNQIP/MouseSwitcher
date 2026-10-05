#!/bin/bash
# MouseSwitcher — 生成 SHA256SUMS 与 Release Notes
#
# 用法：
#   ./scripts/create-release.sh 1.0.0
#
# 产出：
#   dist/SHA256SUMS                 # 所有分发产物的校验和（发布文档 §20）
#   dist/RELEASE_NOTES.md           # 发布说明（发布文档 §18）
#
# 版本号以 Git Tag 为准（发布文档 §19），不要在多个地方手工维护。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MouseSwitcher"
DIST_DIR="$PROJECT_DIR/dist"

VERSION="${1:-${MS_VERSION:-${GITHUB_REF_NAME:-}}}"
VERSION="${VERSION#v}"          # 允许传 v1.0.0 或 1.0.0
[[ -n "$VERSION" ]] || { echo "用法：$0 <版本号>"; exit 1; }

[[ -d "$DIST_DIR" ]] || { echo "❌ 找不到 ${DIST_DIR}，请先运行 ./scripts/package-app.sh"; exit 1; }

echo "==> 生成 SHA256SUMS（版本 ${VERSION}）"
SUMS="$DIST_DIR/SHA256SUMS"
: > "$SUMS"

shopt -s nullglob
ARTIFACTS=("$DIST_DIR/$APP_NAME-macos-"*.zip "$DIST_DIR/$APP_NAME-macos-"*.dmg)
shopt -u nullglob

[[ ${#ARTIFACTS[@]} -gt 0 ]] || { echo "❌ $DIST_DIR 下没有可发布的产物"; exit 1; }

for artifact in "${ARTIFACTS[@]}"; do
    HASH="$(shasum -a 256 "$artifact" | awk '{print $1}')"
    printf '%s  %s\n' "$HASH" "$(basename "$artifact")" >> "$SUMS"
    echo "    $(basename "$artifact")"
    echo "      SHA256: $HASH"
done

# 架构信息从实际产物里读，避免手写 README 时写错
if [[ -f "$PROJECT_DIR/build/$APP_NAME.app/Contents/MacOS/$APP_NAME" ]]; then
    ARCH_INFO="$(file "$PROJECT_DIR/build/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
                 | sed 's/^.*: //')"
else
    ARCH_INFO="未知（未找到已构建的 App）"
fi

echo "==> 生成 RELEASE_NOTES.md"
cat > "$DIST_DIR/RELEASE_NOTES.md" <<NOTES
## MouseSwitcher v$VERSION

A lightweight macOS menu bar utility that moves your mouse pointer between
displays with a global hotkey. / 一个轻量 macOS 菜单栏工具，用全局快捷键
把鼠标指针在多个显示器之间循环切换。

### Changes / 更新内容

- Option + ← / → 在显示器之间切换鼠标，到头自动绕回（循环切换）
- 依据显示器真实空间坐标判断左右关系，不依赖系统数组顺序
- 支持显示器热插拔与屏幕唤醒后的自动刷新
- 菜单栏只显示图标，不显示应用名
- 通用二进制，同时支持 Apple Silicon 与 Intel

### Downloads / 下载

| File | SHA256 |
|---|---|
$(while read -r hash name; do printf '| `%s` | `%s` |\n' "$name" "$hash"; done < "$SUMS")

### Build / 构建信息

- macOS 13.0+ (Ventura)
- $ARCH_INFO
- Swift / SwiftPM, ad-hoc signed (no Developer ID, not notarized)

### Install / 安装

1. 下载 zip 并解压，把 \`MouseSwitcher.app\` 拖进 \`应用程序\`（/Applications）
2. 首次打开若被 Gatekeeper 拦截：右键点击 App → 打开
3. 到 系统设置 → 隐私与安全性 → 辅助功能 勾选 MouseSwitcher
   （这一步必须做，否则快捷键无效）
NOTES

echo ""
echo "✅ 已生成："
echo "   $SUMS"
echo "   $DIST_DIR/RELEASE_NOTES.md"
