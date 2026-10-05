import Foundation
import AppKit

/// 菜单里的「卸载」流程。
///
/// 三件事必须按顺序做对，否则会留下垃圾：
/// 1. 登录项（SMAppService）**必须在 App 还在的时候取消**——App 删掉之后再
///    unregister 就没有对应的 bundle 了，系统设置里只会剩一条灰色失效条目。
/// 2. App 走 `trashItem` 进废纸篓而不是 `rm`，用户可以反悔。
/// 3. 偏好设置（UserDefaults 持久域）要显式移除，拖到废纸篓不会带走它。
///
/// 唯一做不到的是辅助功能授权（TCC 数据库），第三方无权修改，只能引导用户
/// 去系统设置手动移除。
enum Uninstaller {

    private static var bundleID: String {
        Bundle.main.bundleIdentifier ?? "com.local.MouseSwitcher"
    }

    // MARK: - 入口

    /// 弹确认框 → 执行 → 报告结果。
    static func runFromMenu() {
        guard confirm() else {
            Log.info("卸载已取消")
            return
        }
        let report = perform()
        Log.info("卸载完成：\(report.summary)")
        report.show()
    }

    // MARK: - 步骤

    private static func confirm() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "卸载 MouseSwitcher？"
        alert.informativeText = """
        将完成以下操作：

        · 取消开机启动
        · 把 MouseSwitcher.app 移到废纸篓
        · 删除它的偏好设置

        唯一需要你手动处理的是「辅助功能」授权条目，
        卸载后会帮你打开系统设置对应页面。
        """
        alert.addButton(withTitle: "卸载")
        alert.addButton(withTitle: "取消")

        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private struct Report {
        var appTrashed = false
        var loginItemRemoved: Bool?
        var defaultsCleared = false
        var failures: [String] = []

        var summary: String {
            var parts: [String] = []
            parts.append(appTrashed ? "App 已进废纸篓" : "App 未删除")
            if let removed = loginItemRemoved {
                parts.append(removed ? "登录项已取消" : "登录项取消失败")
            }
            parts.append(defaultsCleared ? "设置已清除" : "设置未清除")
            return parts.joined(separator: "，")
        }

        var succeeded: Bool { appTrashed }

        func show() {
            let alert = NSAlert()
            alert.addButton(withTitle: "好")

            if succeeded {
                alert.alertStyle = .informational
                alert.messageText = "卸载完成"
                var text = "MouseSwitcher 已移到废纸篓，偏好设置已清除。"
                if !failures.isEmpty {
                    text += "\n\n未完成的部分：\n· " + failures.joined(separator: "\n· ")
                }
                text += """

                最后一步：在刚打开的系统设置里，
                选中 MouseSwitcher 并点下方的减号 —，移除授权条目。
                """
                alert.informativeText = text
            } else {
                alert.alertStyle = .warning
                alert.messageText = "未能完成卸载"
                let detail = failures.isEmpty ? "未知原因" : "· " + failures.joined(separator: "\n· ")
                alert.informativeText = """
                \(detail)

                可以手动完成：把 MouseSwitcher.app 拖到废纸篓，
                再运行仓库里的 ./uninstall.sh 清理剩余项。
                """
            }

            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()

            // 只有 App 真的被移走了才值得去清授权条目。
            if succeeded {
                PermissionManager.openSystemSettings()
                NSApp.terminate(nil)
            }
        }
    }

    private static func perform() -> Report {
        var report = Report()

        // 1. 登录项（必须在删 App 之前）
        if LaunchAtLoginManager.isAvailable && LaunchAtLoginManager.isEnabled {
            switch LaunchAtLoginManager.setEnabled(false) {
            case .success:
                report.loginItemRemoved = true
            case .failure(let message):
                report.loginItemRemoved = false
                report.failures.append("取消开机启动失败：\(message)")
            }
        }

        // 2. App → 废纸篓
        let appURL = Bundle.main.bundleURL
        do {
            try FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
            report.appTrashed = true
        } catch {
            report.failures.append("移到废纸篓失败：\(error.localizedDescription)")
        }

        // 3. 偏好设置（放在最后，避免被后续写入重新落盘）
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        UserDefaults.standard.synchronize()
        report.defaultsCleared = true

        return report
    }
}
