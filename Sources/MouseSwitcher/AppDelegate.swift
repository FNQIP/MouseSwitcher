import Foundation
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    static let shared = AppDelegate()

    private var menuController: StatusMenuController?
    private var permissionTimer: Timer?
    private var lastTrustedState: Bool?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏应用：不显示 Dock 图标，也不显示普通窗口。
        NSApp.setActivationPolicy(.accessory)

        let displays = DisplayManager.shared.refresh()
        Log.info("Display count: \(displays.count)")
        for display in displays {
            Log.info("  · \(display.name) \(Int(display.frame.width))×\(Int(display.frame.height)) "
                     + "origin=(\(Int(display.frame.minX)), \(Int(display.frame.minY)))"
                     + "\(display.isMain ? " [主显示器]" : "")")
        }

        menuController = StatusMenuController()
        menuController?.rebuildMenu()
        menuController?.refreshStatusItem()

        setupDisplayObservation()
        setupHotKeys()
        setupPermissionMonitoring()
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        permissionTimer = nil
        HotKeyManager.shared.unregister()
    }

    /// 应用已在运行时，用户再次从 Finder / Spotlight / Dock 点击图标会走到这里。
    /// 菜单栏应用没有窗口，直接弹出菜单，避免「点了没反应」的错觉。
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuController?.popUpMenu()
        return false
    }

    // MARK: - 快捷键

    private func setupHotKeys() {
        HotKeyManager.shared.onHotKey = { [weak self] direction in
            self?.menuController?.refreshStatusItem()
            SwitchCoordinator.shared.move(direction: direction == .left ? .left : .right)
        }

        let okay = HotKeyManager.shared.register()
        if !okay {
            Log.warn("部分快捷键注册失败，仍可通过菜单栏手动切换")
        }
    }

    // MARK: - 显示器变化

    private func setupDisplayObservation() {
        DisplayManager.shared.onChange = { [weak self] in
            self?.menuController?.refreshStatusItem()
        }
        DisplayManager.shared.registerReconfigurationCallback()
    }

    // MARK: - 权限监控

    /// 低频（2 秒）检测权限变化，使用户授权后无需重启应用。
    /// 仅在尚未获得权限时运行，拿到权限后立即停止，避免无谓开销。
    private func setupPermissionMonitoring() {
        lastTrustedState = PermissionManager.isTrusted()

        if lastTrustedState == true {
            Log.info("已获得 Accessibility 权限")
            return
        }

        Log.warn("尚未获得 Accessibility 权限，快捷键暂时无法移动鼠标")
        PermissionManager.requestPermission()

        permissionTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] timer in
            guard let self else { timer.invalidate(); return }

            let trusted = PermissionManager.isTrusted()
            if trusted != self.lastTrustedState {
                self.lastTrustedState = trusted
                Log.info(trusted ? "已获得 Accessibility 权限，快捷键现在可用" : "Accessibility 权限被撤销")
                self.menuController?.refreshStatusItem()
            }

            if trusted {
                timer.invalidate()
                self.permissionTimer = nil
            }
        }
        permissionTimer?.tolerance = 0.5
        RunLoop.main.add(permissionTimer!, forMode: .common)
    }
}
