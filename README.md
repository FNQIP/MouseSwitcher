# MouseSwitcher

![Swift](https://img.shields.io/badge/Swift-6.1-orange.svg)
![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue.svg)
![Arch](https://img.shields.io/badge/Arch-Universal%20(arm64%20%2B%20x86__64)-green.svg)

> 一个极小的 macOS 菜单栏工具：按 `Option + ←` / `Option + →`，
> 把鼠标指针在多个显示器之间循环切换。
>
> [English](./README.en.md)

<img src="./docs/app-icon.png" width="128" alt="MouseSwitcher 应用图标" />

它实际出现在屏幕右上角，只有一个图标、不显示应用名：

<img src="./docs/menu-bar.png" width="480" alt="菜单栏中的 MouseSwitcher" />

---

## 为什么需要它

macOS 原生只能在「显示器排列」里靠鼠标**推动边缘**跨屏。当你外接一两台显示器、
尤其是分辨率不同或上下错位时，指针常常卡在边缘过不去。MouseSwitcher 做的是
**按一次键就把指针直接落到目标屏幕的对应位置**，并且可以在屏幕之间循环。

---

## 功能

- **`Option + →` / `Option + ←`** — 全局快捷键，切换到下一个 / 上一个显示器
- **循环切换**（默认开启）— 走到最左或最右会自动绕回另一端，
  所以你**不需要判断该按哪个方向**，一直按同一个键就能遍历所有屏幕
- **保持相对位置** — 指针落在目标屏幕的相对位置（例如左屏 50% / 50%
  就落到右屏 50% / 50%），可关闭，关闭后落到屏幕中心
- **按真实空间坐标判断左右** — 使用 `CGDisplayBounds` 的全局坐标计算，
  不依赖系统返回数组的顺序，错位排列、不同分辨率都能正确判断
- **热插拔与唤醒自动刷新** — 拔插外接屏、休眠唤醒后自动重建屏幕列表
- **只驻留菜单栏** — 不在 Dock 显示图标（`LSUIElement`），不弹窗口
- **通用二进制** — 同时支持 Apple Silicon（M 系列）与 Intel，不需要 Rosetta
- **开机启动** — 可在菜单里一键开关

---

## 系统要求

| 项目 | 要求 |
|---|---|
| 系统 | macOS 13.0 (Ventura) 及以上 |
| 芯片 | Apple Silicon / Intel（通用二进制） |
| 显示器 | **2 台及以上才有意义**（单显示器时按快捷键不做任何事） |

---

## 下载与安装

### 1. 下载

从 [Releases](https://github.com/FNQIP/MouseSwitcher/releases) 页面下载
`MouseSwitcher-macos-universal.zip`，解压后得到 `MouseSwitcher.app`，
把它拖进 `应用程序`（/Applications）。

想先验证完整性可以核对 Release 里的 `SHA256SUMS`：

```bash
shasum -a 256 -c SHA256SUMS
```

### 2. 首次打开可能被 Gatekeeper 拦截 ⚠️

本项目**没有使用付费的 Apple Developer 证书**，只有本地 ad-hoc 签名、未做公证，
所以首次打开时 macOS 可能提示「来自身份不明的开发者」或「文件已损坏」。
**这不是 App 有问题**，三种解法任选其一：

1. **右键**点击 MouseSwitcher.app → 「打开」→ 再点「打开」确认
2. 终端执行：
   ```bash
   xattr -cr /Applications/MouseSwitcher.app
   ```
3. 系统设置 → 隐私与安全性 → 下滑到「安全性」→ 点「仍要打开」

### 3. 必须手动授权「辅助功能」 ⚠️

鼠标控制需要 Accessibility 权限，**这一步无法自动化，只能由你本机授权**：

```
系统设置 → 隐私与安全性 → 辅助功能 → 勾选 MouseSwitcher
```

也可以直接点击菜单栏图标 → 「打开系统设置…」跳转过去。
授权后**无需重启**，几秒内自动生效（未授权时菜单栏图标旁会显示 ⚠️）。

> Dock 里不会出现它的图标，这是菜单栏应用的正常设计。
> 判断有没有运行，看屏幕右上角有没有那个双屏图标。

---

## 使用方法

| 操作 | 效果 |
|---|---|
| `Option + →` | 鼠标移到下一个显示器（到头自动绕回） |
| `Option + ←` | 鼠标移到上一个显示器（循环） |
| 点击菜单栏图标 | 打开菜单 |

菜单里可以：手动选择要移到哪台显示器、开关循环切换、
开关「保持相对位置」、开关开机启动、打开系统设置、卸载、退出。

**循环说明**：方向只决定遍历顺序。任意方向连续按都能遍历到所有显示器，
到最右 / 最左时自动绕回，不会卡住。三屏以上时中间仍按空间邻居跳转，只在两端绕回。

---

## 卸载

### 方式一：菜单栏里点一下（推荐）

点菜单栏图标 → **「卸载 MouseSwitcher…」** → 确认。会自动：

1. 取消开机启动（SMAppService 登录项，必须在 App 还在时取消）
2. 把 `MouseSwitcher.app` 移进**废纸篓**（还能反悔）
3. 删除 `com.local.MouseSwitcher` 的偏好设置
4. 打开系统设置 → 隐私与安全性 → 辅助功能，供你移除授权条目

### 方式二：脚本

```bash
./uninstall.sh
```

做的事和方式一相同（区别是 App 直接删除而非进废纸篓），并额外用
`tccutil` 清除辅助功能授权记录。

### 方式三：拖到废纸篓

访达里把 `MouseSwitcher.app` 拖到废纸篓，能删掉 App 本体，但**会残留**
开机启动项和偏好设置。想彻底清干净请用上面两种方式，或拖完再跑一次
`./uninstall.sh` 补清理。

### 无论如何都要手动的一步

**辅助功能授权**（系统 TCC 数据库）第三方无权修改，只能手动移除：
系统设置 → 隐私与安全性 → 辅助功能 → 选中 MouseSwitcher → 点减号 —。
该列表有时要重新打开系统设置才刷新。

卸载后建议在**系统设置 → 隐私与安全性 → 辅助功能**里确认该条目已消失
（该列表有时要等系统设置重新打开才刷新），登录项同理。

验证是否卸干净：

```bash
mdfind "kMDItemCFBundleIdentifier == 'com.local.MouseSwitcher'"   # 应无输出
pgrep -fl MouseSwitcher                                            # 应无输出
```

> 旧版本（2026-10-06 之前）的 `uninstall.sh` 只删 `~/Applications`，
> 而 `install.sh` 默认装的是 `/Applications`，会漏掉。现在两处都覆盖。

---

## 从源码构建

不需要 Xcode，只需要 **Xcode Command Line Tools**（`xcode-select --install`），
也不需要 Apple Developer 账号。

```bash
git clone https://github.com/FNQIP/MouseSwitcher.git
cd MouseSwitcher
./scripts/build-app.sh          # 产出 build/MouseSwitcher.app（arm64 + x86_64）
open build/MouseSwitcher.app
```

只给自己用的话可以只编译本机架构，会快一些：

```bash
./scripts/build-app.sh --native
```

### 仓库里的脚本

| 脚本 | 作用 |
|---|---|
| `scripts/build-app.sh` | 构建 App Bundle（默认通用二进制，支持 `--version`） |
| `scripts/package-app.sh` | 打包成 `MouseSwitcher-macos-universal.zip`（可选 `--dmg`） |
| `scripts/create-release.sh` | 生成 `SHA256SUMS` 与 Release Notes |
| `install.sh` | 安装到 `/Applications`（不可写时退回 `~/Applications`） |
| `run-app.sh` | 构建并启动 |
| `uninstall.sh` | 卸载：清登录项、删 App（两处）、清偏好设置与辅助功能授权 |
| `dist.sh` | 生成带安装器和使用说明的分发包 |

---

## 项目结构

```text
MouseSwitcher/
├── Package.swift                 SwiftPM 清单
├── Info.plist                    App 配置（LSUIElement=true）
├── Sources/MouseSwitcher/        Swift 源码
│   ├── AppDelegate.swift         应用生命周期
│   ├── StatusMenuController.swift 菜单栏与菜单
│   ├── DisplayManager.swift      显示器枚举与左右关系求解
│   ├── MouseManager.swift        鼠标移动
│   ├── HotKeyManager.swift       全局快捷键（Carbon）
│   ├── PermissionManager.swift   Accessibility 权限
│   ├── SettingsManager.swift     偏好设置
│   ├── SwitchCoordinator.swift   切换流程编排
│   ├── LaunchAtLoginManager.swift 开机启动
│   └── Diagnostics.swift         --diagnose / --move 调试开关
├── Resources/                    应用图标（.icns）与菜单栏模板图
├── Tools/make-icon.swift         图标生成器（CoreGraphics 矢量绘制）
├── scripts/                      构建 / 打包 / 发布脚本
└── .github/workflows/            GitHub Actions
```

图标不是位图素材，而是由 `Tools/make-icon.swift` 用 CoreGraphics **矢量绘制**
并按每个尺寸原生渲染，因此 16px 到 1024px 都清晰，也不引入任何第三方依赖。

---

## CI / CD

仓库配置了两个 GitHub Actions 工作流：

| 触发 | 工作流 | 结果 |
|---|---|---|
| push 到 `main` / Pull Request | `build.yml` | 编译 + 校验 + 打包，产物上传到 **Actions Artifacts** |
| push `v*` 标签 | `release.yml` | 额外创建 **GitHub Release**，附 zip、dmg 与 `SHA256SUMS` |

发布新版本：

```bash
git tag v1.0.0
git push origin v1.0.0
```

版本号以 Git Tag 为唯一来源，构建时写入 `Info.plist`，不需要在多处手工维护。
构建失败会直接让工作流失败，不会发布损坏的产物。

---

## 已知限制

- **未做公证**：ad-hoc 签名，首次打开需按上面第 2 步放行。
  想彻底消除提示需要 Apple Developer Program（付费）的 Developer ID 签名 + 公证。
- **重建会使权限失效**：ad-hoc 签名每次构建都会变化，导致之前授予的
  辅助功能权限失效，需要重新勾选一次。日常使用不重新构建就不会掉。
- 单显示器环境下按快捷键不产生任何动作。

---

## 隐私

- 不联网、不采集任何数据、不上传日志
- 只申请 **辅助功能** 权限，用途仅为读取显示器布局与移动鼠标指针
- 日志默认只打印到控制台（可在菜单里关闭）
