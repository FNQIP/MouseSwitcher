import Foundation
import AppKit
import ApplicationServices

/// Accessibility（辅助功能）权限管理。
///
/// 缺少权限时应用必须继续正常运行，只做提示，不崩溃。
enum PermissionManager {

    private static let settingsURLString =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    private static let legacySettingsPath =
        "/System/Library/PreferencePanes/Security.prefPane"

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// 弹出系统授权对话框。
    @discardableResult
    static func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// 用户按下快捷键但无权限时的提示（菜单栏状态 + 系统授权窗口）。
    static func notifyMissingPermission() {
        Log.warn("Accessibility 权限未开启")
        DispatchQueue.main.async {
            requestPermission()
            StatusMenuController.shared?.refreshStatusItem()
        }
    }

    /// 打开系统设置的辅助功能页面。
    static func openSystemSettings() {
        guard let url = URL(string: settingsURLString) else {
            openLegacySettings()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error {
                Log.warn("无法使用 URL Scheme 打开系统设置：\(error.localizedDescription)")
                openLegacySettings()
            }
        }
    }

    /// 兼容方案：旧版 macOS 不支持该 URL Scheme 时直接打开 prefPane。
    private static func openLegacySettings() {
        let url = URL(fileURLWithPath: legacySettingsPath)
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error {
                Log.warn("无法打开系统设置：\(error.localizedDescription)")
                Log.warn("请手动前往 系统设置 → 隐私与安全性 → 辅助功能")
            }
        }
    }
}
