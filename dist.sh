#!/bin/bash
# MouseSwitcher — 制作可分发的安装包
#
# 用法：
#   ./dist.sh            # 生成 zip（默认，最通用）
#   ./dist.sh --dmg      # 生成 dmg 磁盘镜像（更像正式发布版）
#
# 产出：
#   dist/MouseSwitcher-<版本>-universal.zip   （或 .dmg）
#
# 包内含：
#   MouseSwitcher.app                 通用二进制（arm64 + x86_64）
#   拖入应用程序文件夹.command        双击即可安装
#   卸载 MouseSwitcher.command        双击即可卸载
#   使用说明.md                       安装/授权/使用说明
#
# ⚠️ 关于 Gatekeeper：
#   本项目用的是 ad-hoc 自签名（不需要 Apple 开发者账号）。对方第一次打开时
#   macOS 可能拦截，提示「来自身份不明的开发者」或「文件已损坏」。
#   处理方式写在《使用说明.md》里，最稳的一条命令是：
#       xattr -cr MouseSwitcher.app
#   想彻底消除这个提示，必须用付费的 Developer ID 证书签名 + 公证
#   （Apple Developer Program，¥688/年），见 dist.sh 末尾注释。

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

APP_NAME="MouseSwitcher"
SOURCE_APP="$PROJECT_DIR/build/$APP_NAME.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Info.plist" 2>/dev/null || echo 1.0.0)"

FORMAT="zip"
[[ "${1:-}" == "--dmg" ]] && FORMAT="dmg"

if [[ ! -d "$SOURCE_APP" ]]; then
    echo "==> 未找到已构建的 App，先执行构建…"
    ./scripts/build-app.sh
fi

# 分发前必须确认是通用二进制，否则 Apple Silicon 的机器会因为缺 Rosetta 打不开
if ! file "$SOURCE_APP/Contents/MacOS/$APP_NAME" | grep -q "universal binary"; then
    echo "❌ 当前 App 不是通用二进制，Apple Silicon 机器可能无法运行。"
    echo "   请重新执行：./build-app.sh（不要加 --native）"
    exit 1
fi

STAGE="$PROJECT_DIR/build/dist-stage"
PKG_DIR="$STAGE/$APP_NAME-$VERSION"
DIST_DIR="$PROJECT_DIR/dist"

rm -rf "$STAGE"
mkdir -p "$PKG_DIR" "$DIST_DIR"

echo "==> [1/4] 复制 App"
cp -R "$SOURCE_APP" "$PKG_DIR/$APP_NAME.app"

echo "==> [2/4] 生成安装 / 卸载脚本"

cat > "$PKG_DIR/拖入应用程序文件夹.command" <<'SCRIPT'
#!/bin/bash
# MouseSwitcher 安装器 — 双击运行即可
cd "$(dirname "$0")"

APP="$(cd "$(dirname "$0")" && pwd)/MouseSwitcher.app"

if [[ ! -d "$APP" ]]; then
    echo "❌ 找不到 MouseSwitcher.app，请确认它与本文件在同一目录下。"
    read -r -p "按回车键关闭…"
    exit 1
fi

# macOS 会给从网络/AirDrop 得来的文件打上隔离标记，导致系统拒绝打开。
# 这里在拷贝前先清掉，省去「右键 → 打开」这一步。
echo "==> 清除隔离标记"
xattr -cr "$APP" 2>/dev/null || true

TARGET="/Applications"
if [[ ! -w "$TARGET" ]]; then
    echo "⚠️  /Applications 不可写，改为安装到 ~/Applications"
    TARGET="$HOME/Applications"
fi
mkdir -p "$TARGET"

echo "==> 退出正在运行的实例…"
pkill -f "MouseSwitcher.app/Contents/MacOS/MouseSwitcher" 2>/dev/null || true
sleep 1

echo "==> 安装到 $TARGET"
rm -rf "$TARGET/MouseSwitcher.app"
cp -R "$APP" "$TARGET/MouseSwitcher.app"

echo "==> 启动"
open "$TARGET/MouseSwitcher.app" 2>/dev/null || true
sleep 2

echo ""
echo "✅ 安装完成：$TARGET/MouseSwitcher.app"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "还需要做一件事：授权辅助功能权限"
echo ""
echo "菜单栏右上角出现它的图标后，点击菜单里的"
echo "「打开系统设置…」，在 隐私与安全性 → 辅助功能"
echo "中勾选 MouseSwitcher。"
echo ""
echo "若菜单栏没有出现任何图标，说明系统拦截了启动，"
echo "请阅读同目录的《使用说明.md》。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -r -p "按回车键关闭…"
SCRIPT

cat > "$PKG_DIR/卸载 MouseSwitcher.command" <<'SCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

APP_NAME="MouseSwitcher"
BUNDLE_ID="com.local.MouseSwitcher"

echo "==> 退出 ${APP_NAME}…"
pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
sleep 1

# 登录项必须在 App 还存在时取消，否则系统设置里会留一条灰色失效条目。
echo "==> 取消开机启动（如已开启）"
for app in "/Applications/${APP_NAME}.app" "$HOME/Applications/${APP_NAME}.app"; do
    bin="$app/Contents/MacOS/${APP_NAME}"
    [[ -x "$bin" ]] || continue
    # 旧版二进制不认识这个参数，会当成正常启动，先探测再调用
    strings "$bin" 2>/dev/null | grep -q -- "--unregister-login" || continue
    "$bin" --unregister-login >/dev/null 2>&1 && echo "    ✓ 已移除登录项" && break
done

for dir in "/Applications" "$HOME/Applications"; do
    if [[ -d "$dir/${APP_NAME}.app" ]]; then
        echo "==> 删除 $dir/${APP_NAME}.app"
        rm -rf "$dir/${APP_NAME}.app" 2>/dev/null || echo "    ⚠️  删除失败（权限不足），请手动拖到废纸篓"
    fi
done

echo "==> 清除偏好设置"
defaults delete ${BUNDLE_ID} 2>/dev/null || true

echo "==> 清除辅助功能授权记录"
tccutil reset Accessibility ${BUNDLE_ID} 2>/dev/null || true

echo ""
echo "✅ 已卸载。"
echo "   系统设置 → 隐私与安全性 → 辅助功能 里的条目如仍在，"
echo "   选中 ${APP_NAME} 点减号 — 移除即可（重开系统设置会刷新）。"
echo ""
read -r -p "按回车键关闭…"
SCRIPT

chmod +x "$PKG_DIR/拖入应用程序文件夹.command" "$PKG_DIR/卸载 MouseSwitcher.command"

echo "==> [3/4] 生成使用说明"

cat > "$PKG_DIR/使用说明.md" <<'DOC'
# MouseSwitcher 使用说明

一个轻量菜单栏工具：用快捷键把鼠标指针在多个显示器之间循环切换。

---

## 一、安装

双击 **「拖入应用程序文件夹.command」**，按提示回车即可。

它会把 App 复制到 `/Applications`，清除隔离标记并自动启动。

### 如果弹出「无法打开」「文件已损坏」「来自身份不明的开发者」

这是 macOS 的安全机制（Gatekeeper），不是 App 有问题。因为这个版本
使用的是本地自签名，没有向 Apple 申请付费证书，所以系统会拦一道。
**三种解法，任选其一：**

1. **推荐**：在访达里**右键**点击 MouseSwitcher.app → 选「打开」，
   再点「打开」确认。
2. 终端里执行（把路径换成实际的）：
   ```bash
   xattr -cr /Applications/MouseSwitcher.app
   ```
3. 系统设置 → 隐私与安全性 → 下滑到「安全性」→ 点「仍要打开」。

> `.command` 安装脚本本身如果被拦，同样用右键 → 打开的方式运行。

---

## 二、授权（必须做，否则快捷键无效）

菜单栏 App 不会被 Dock 显示。启动后看**屏幕右上角**：

- 看到 ⚠️ 或菜单里提示缺权限 → 点击菜单里的 **「打开系统设置…」**
  → 隐私与安全性 → **辅助功能** → 勾选 **MouseSwitcher**
- 授权后无需重启，几秒内自动生效，图标会变为正常的双屏图形

如果授权列表里已经勾选但依然无效：把勾去掉再勾上，或删除该条目后重启 App。

---

## 三、使用

| 操作 | 效果 |
|---|---|
| `Option + →` | 鼠标移到下一个显示器（到头自动绕回第一个） |
| `Option + ←` | 鼠标移到上一个显示器（循环） |
| 点击菜单栏图标 | 打开菜单，可手动切换、勾选开机启动、退出 |

**循环说明**：方向只是决定遍历顺序，任意方向连续按都能遍历到所有显示器，
到最右/最左时会自动绕回，不会卡住。

单显示器时按快捷键不产生任何动作，属正常。

---

## 四、卸载

**方式一（最省事）**：点菜单栏图标 → **「卸载 MouseSwitcher…」** → 确认。
会自动取消开机启动、把 App 移进废纸篓、清掉偏好设置，并打开系统设置的
辅助功能页面供你移除授权条目。

**方式二**：双击 **「卸载 MouseSwitcher.command」**，效果相同（走命令行）。

**方式三**：直接把 `/Applications/MouseSwitcher.app` 拖到废纸篓。
⚠️ 这样**只删得掉 App 本体**，会残留开机启动项和偏好设置；
建议改用上面两种方式。

无论哪种方式，**辅助功能授权条目**都需要手动移除：
系统设置 → 隐私与安全性 → 辅助功能 → 选中 MouseSwitcher → 点减号 —。

---

## 五、系统要求

- macOS 13.0 (Ventura) 及以上
- 支持 Intel 与 Apple Silicon（通用二进制，无需 Rosetta）
- **需要两个或以上显示器**才能体现功能

---

## 六、源码与自行构建

如果不想信任别人编译好的二进制，可以自己从源码构建：

```bash
git clone <仓库地址> MouseSwitcher
cd MouseSwitcher
./build-app.sh        # 依赖 Xcode Command Line Tools：xcode-select --install
./install.sh
```

`./build-app.sh` 会构建 arm64 + x86_64 双架构通用二进制，
只用到 Swift Package Manager 和系统自带命令，不需要安装 Xcode，
也不需要 Apple 开发者账号。
DOC

echo "==> [4/4] 打包"

OUT_ZIP="$DIST_DIR/$APP_NAME-$VERSION-universal.zip"
OUT_DMG="$DIST_DIR/$APP_NAME-$VERSION-universal.dmg"
rm -f "$OUT_ZIP" "$OUT_DMG"

# zip 会丢失符号链接与部分权限，先把 .command 的可执行位显式确认一遍
chmod +x "$PKG_DIR"/*.command

if [[ "$FORMAT" == "dmg" ]]; then
    TMP_DMG="$STAGE/tmp.dmg"
    hdiutil create -quiet -srcfolder "$PKG_DIR" -volname "$APP_NAME $VERSION" \
        -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 32m "$TMP_DMG"
    hdiutil convert -quiet -format UDZO -imagekey zlib-level=9 \
        -o "$OUT_DMG" "$TMP_DMG"
    ARTIFACT="$OUT_DMG"
else
    (cd "$STAGE" && zip -qry "$OUT_ZIP" "$APP_NAME-$VERSION")
    ARTIFACT="$OUT_ZIP"
fi

echo ""
echo "✅ 分发包已生成"
echo "   $ARTIFACT"
echo "   $(du -h "$ARTIFACT" | awk '{print $1}')"
echo ""
if [[ "$FORMAT" == "dmg" ]]; then
    echo "   收到方操作：双击挂载磁盘镜像 → 把 MouseSwitcher.app 拖进 Applications"
    echo "   （或从镜像里双击《拖入应用程序文件夹.command》）"
else
    echo "   收到方操作：解压 → 双击《拖入应用程序文件夹.command》"
fi
echo ""
echo "⚠️  务必提醒对方先读《使用说明.md》里的「Gatekeeper / 授权」两节，"
echo "    否则很容易卡在「打不开」或「按了快捷键没反应」。"

# ─────────────────────────────────────────────────────────────
# 想让对方免去右键打开的麻烦，必须用付费证书签名 + 公证：
#
#   # 1. 签名（Developer ID Application 证书）
#   codesign --force --deep --options runtime \
#            --timestamp --sign "Developer ID Application: XXX (TEAMID)" \
#            build/MouseSwitcher.app
#
#   # 2. 打包并上传公证
#   ditto -c -k --keepParent build/MouseSwitcher.app MS.zip
#   xcrun notarytool submit MS.zip --apple-id ID --team-id TEAMID \
#            --password <app专用密码> --wait
#
#   # 3. 把公证结果（票据）钉到 App 上，离线也能通过检查
#   xcrun stapler staple build/MouseSwitcher.app
#
# 需要 Apple Developer Program 会员资格（¥688/年）。
# ─────────────────────────────────────────────────────────────
