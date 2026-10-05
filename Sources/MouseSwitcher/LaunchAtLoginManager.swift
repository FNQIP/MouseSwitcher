import Foundation
import ServiceManagement
import AppKit

/// 开机启动管理。
///
/// macOS 13+ 使用 SMAppService（ServiceManagement），
/// 不需要 helper app，也不写入系统目录。
enum LaunchAtLoginManager {

    static var isAvailable: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    static var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    enum ToggleResult {
        case success(Bool)
        case failure(String)
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> ToggleResult {
        guard #available(macOS 13.0, *) else {
            return .failure("当前 macOS 版本不支持 SMAppService")
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.info("开机启动已\(enabled ? "开启" : "关闭")")
            return .success(enabled)
        } catch {
            let message = "开机启动设置失败：\(error.localizedDescription)"
            Log.error(message)
            return .failure(message)
        }
    }

    @discardableResult
    static func toggle() -> ToggleResult {
        setEnabled(!isEnabled)
    }
}
