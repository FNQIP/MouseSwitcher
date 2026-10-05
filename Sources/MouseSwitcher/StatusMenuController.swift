import Foundation
import AppKit

/// 菜单栏 UI：状态项 + 动态菜单。
final class StatusMenuController: NSObject, NSMenuDelegate {

    static weak var shared: StatusMenuController?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private var titleItem: NSMenuItem!
    private var currentDisplayItem: NSMenuItem!
    private var permissionItem: NSMenuItem?
    private var openSettingsItem: NSMenuItem?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        Self.shared = self

        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            button.image = Self.menuBarImage
            // 图形按自身尺寸绘制，不做二次缩放，避免额外模糊
            button.imageScaling = .scaleNone
            button.toolTip = "MouseSwitcher — 用 Option + ← / → 在显示器之间切换鼠标"
        }
    }

    /// 菜单栏图形显示尺寸（点）。必须与 Tools/make-icon.swift 中
    /// `chosenMenuBarVariant.pointSize` 完全一致，否则会被系统二次缩放。
    private static let menuBarPointSize = CGSize(width: 26, height: 12)

    /// 菜单栏图形：模板图，只取 alpha，颜色跟随菜单栏明暗。
    ///
    /// 注意：这里必须手动把 1x / 2x 两档位图装进同一个 NSImage。
    /// `NSImage(contentsOf:)` 只会读入指定的那一个文件——macOS 的 `@2x`
    /// 自动匹配仅对 `NSImage(named:)` 生效。少装 2x 档的话，Retina 屏上
    /// 系统会把 1x 位图放大两倍来用，状态栏图标就会糊。
    private static let menuBarImage: NSImage? = {
        let bundle = Bundle.main
        let image = NSImage(size: menuBarPointSize)

        var loaded = 0
        for file in ["menubar.png", "menubar@2x.png"] {
            let base = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            let url = bundle.url(forResource: base, withExtension: ext, subdirectory: "Assets")
                ?? bundle.url(forResource: base, withExtension: ext)
            guard let url, let rep = NSImageRep(contentsOf: url) else {
                Log.warn("菜单栏图标缺少 \(file)")
                continue
            }
            // 位图的像素尺寸保留，逻辑尺寸统一成 pointSize，
            // NSImage 会按屏幕缩放比自动挑最合适的一档。
            rep.size = menuBarPointSize
            image.addRepresentation(rep)
            loaded += 1
        }

        guard loaded > 0 else {
            Log.warn("菜单栏图标加载失败，回退到 emoji")
            return nil
        }

        image.isTemplate = true
        let detail = image.representations
            .map { "\($0.pixelsWide)x\($0.pixelsHigh)px/\(Int($0.size.width))x\(Int($0.size.height))pt" }
            .joined(separator: " ")
        Log.info("菜单栏图标已加载：\(loaded) 档分辨率，size=\(Int(image.size.width))x\(Int(image.size.height))pt [\(detail)]")
        return image
    }()

    // MARK: - 状态项

    /// 状态栏只显示图形，不显示应用名称。
    /// 未授权时在图形后追加一个警示符号（完整说明在菜单里）。
    ///
    /// 注意：这里刻意不使用 `appearsDisabled`。它会把状态项整体渲染成半透明，
    /// 在这种小尺寸线条图形上会被误认为「图标糊了」。未授权状态用 ⚠️ 表达即可。
    func refreshStatusItem() {
        let trusted = PermissionManager.isTrusted()

        if let button = statusItem.button {
            if Self.menuBarImage != nil {
                button.image = Self.menuBarImage
                button.title = trusted ? "" : " ⚠️"
            } else {
                button.image = nil
                button.title = trusted ? "🖥" : "⚠️"
            }

            button.toolTip = trusted
                ? "MouseSwitcher — Option + ← / → 在显示器之间切换鼠标"
                : "MouseSwitcher 需要「辅助功能」权限才能控制鼠标。\n点开菜单 → 打开系统设置…"
        }
    }

    /// 主动弹出菜单栏菜单。
    /// 用于在「应用已在运行，用户又点了一次图标」时给出可见反馈。
    func popUpMenu() {
        DisplayManager.shared.refresh()
        rebuildMenu()
        refreshStatusItem()
        statusItem.button?.performClick(nil)
    }

    // MARK: - 菜单构建

    func rebuildMenu() {
        menu.removeAllItems()

        // 标题
        let header = NSMenuItem(title: "MouseSwitcher", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let version = NSMenuItem(
            title: "版本 \(Self.appVersion)  ·  \(DisplayManager.shared.displays.count) 个显示器",
            action: nil,
            keyEquivalent: ""
        )
        version.isEnabled = false
        menu.addItem(version)

        menu.addItem(.separator())

        // 权限
        if !PermissionManager.isTrusted() {
            let warning = NSMenuItem(title: "⚠️ Accessibility 权限未开启", action: nil, keyEquivalent: "")
            warning.isEnabled = false
            menu.addItem(warning)
            permissionItem = warning

            let enable = NSMenuItem(
                title: "打开系统设置…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            enable.target = self
            menu.addItem(enable)
            openSettingsItem = enable

            let request = NSMenuItem(
                title: "请求授权…",
                action: #selector(requestAccessibility),
                keyEquivalent: ""
            )
            request.target = self
            menu.addItem(request)

            menu.addItem(.separator())
        } else {
            permissionItem = nil
            openSettingsItem = nil
        }

        // 当前显示器
        let currentName = MouseManager.shared.currentDisplay()?.name ?? "未知"
        let current = NSMenuItem(title: "当前显示器： ● \(currentName)", action: nil, keyEquivalent: "")
        current.isEnabled = false
        menu.addItem(current)
        currentDisplayItem = current

        menu.addItem(.separator())

        // 显示器列表
        let listHeader = NSMenuItem(title: "显示器", action: nil, keyEquivalent: "")
        listHeader.isEnabled = false
        menu.addItem(listHeader)

        let displays = DisplayManager.shared.displays
        if displays.isEmpty {
            let none = NSMenuItem(title: "  未检测到显示器", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            let currentID = MouseManager.shared.currentDisplay()?.id
            for display in displays {
                let marker = display.id == currentID ? "● " : "○ "
                let flag = display.isMain ? "（主显示器）" : ""
                let size = "\(Int(display.size.width))×\(Int(display.size.height))"
                let item = NSMenuItem(
                    title: "  \(marker)\(display.name)  \(size)\(flag)",
                    action: #selector(moveToDisplay(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = NSNumber(value: display.id)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // 快捷操作
        let leftItem = NSMenuItem(
            title: "移到左侧显示器",
            action: #selector(moveLeft),
            keyEquivalent: ""
        )
        leftItem.target = self
        leftItem.representedObject = "left"
        menu.addItem(leftItem)

        let rightItem = NSMenuItem(
            title: "移到右侧显示器",
            action: #selector(moveRight),
            keyEquivalent: ""
        )
        rightItem.target = self
        rightItem.representedObject = "right"
        menu.addItem(rightItem)

        let hint = NSMenuItem(title: "快捷键：Option + ← / Option + →", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        // 设置项
        let wrap = NSMenuItem(
            title: "循环切换（到最左/最右后绕回另一端）",
            action: #selector(toggleWrapAround(_:)),
            keyEquivalent: ""
        )
        wrap.target = self
        wrap.state = SettingsManager.shared.wrapAround ? .on : .off
        menu.addItem(wrap)

        let preserve = NSMenuItem(
            title: "切换时保持相对位置",
            action: #selector(togglePreserveRelativePosition(_:)),
            keyEquivalent: ""
        )
        preserve.target = self
        preserve.state = SettingsManager.shared.preserveRelativePosition ? .on : .off
        menu.addItem(preserve)

        if LaunchAtLoginManager.isAvailable {
            let login = NSMenuItem(
                title: "开机启动",
                action: #selector(toggleLaunchAtLogin(_:)),
                keyEquivalent: ""
            )
            login.target = self
            login.state = LaunchAtLoginManager.isEnabled ? .on : .off
            menu.addItem(login)
        }

        let rescan = NSMenuItem(
            title: "重新检测显示器",
            action: #selector(rescanDisplays),
            keyEquivalent: ""
        )
        rescan.target = self
        menu.addItem(rescan)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "退出 MouseSwitcher",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        DisplayManager.shared.refresh()
        rebuildMenu()
        refreshStatusItem()
    }

    func menuDidClose(_ menu: NSMenu) {
        refreshStatusItem()
    }

    // MARK: - Actions

    @objc private func moveLeft() {
        SwitchCoordinator.shared.move(direction: .left)
    }

    @objc private func moveRight() {
        SwitchCoordinator.shared.move(direction: .right)
    }

    @objc private func moveToDisplay(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        let id = CGDirectDisplayID(number.uint32Value)
        SwitchCoordinator.shared.move(to: id)
    }

    @objc private func toggleWrapAround(_ sender: NSMenuItem) {
        let manager = SettingsManager.shared
        manager.wrapAround.toggle()
        sender.state = manager.wrapAround ? .on : .off
        Log.info("循环切换：\(manager.wrapAround ? "开" : "关")")
    }

    @objc private func togglePreserveRelativePosition(_ sender: NSMenuItem) {
        let manager = SettingsManager.shared
        manager.preserveRelativePosition.toggle()
        sender.state = manager.preserveRelativePosition ? .on : .off
        Log.info("保持相对位置：\(manager.preserveRelativePosition ? "开" : "关")")
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        switch LaunchAtLoginManager.toggle() {
        case .success(let enabled):
            sender.state = enabled ? .on : .off
        case .failure(let message):
            Log.error(message)
            showAlert(title: "开机启动", message: message)
        }
    }

    @objc private func rescanDisplays() {
        let displays = DisplayManager.shared.refresh()
        Log.info("手动重新检测，Display count: \(displays.count)")
        rebuildMenu()
        refreshStatusItem()
    }

    @objc private func openAccessibilitySettings() {
        PermissionManager.openSystemSettings()
    }

    @objc private func requestAccessibility() {
        let trusted = PermissionManager.requestPermission()
        Log.info("请求 Accessibility 授权：\(trusted ? "已授权" : "等待用户授权")")
    }

    // MARK: - 辅助

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}
