import Foundation
import AppKit
import CoreGraphics

/// 命令行自检工具。
///
/// 菜单栏应用没有窗口，排查显示器拓扑不方便，因此提供两个调试开关：
///
///   MouseSwitcher --diagnose        打印显示器拓扑与左右关系
///   MouseSwitcher --move left|right 直接执行一次切换（等价于按快捷键）
///
/// 正常启动（open MouseSwitcher.app）不会进入这条分支。
enum Diagnostics {

    static func run(move argument: String?) {
        let displays = DisplayManager.shared.refresh()

        print("=== MouseSwitcher 自检 ===")
        print("Accessibility 权限: \(PermissionManager.isTrusted() ? "已授权" : "未授权")")
        print("显示器数量: \(displays.count)")

        for (index, display) in displays.enumerated() {
            let f = display.frame
            print(String(
                format: "  [%d] %@  %dx%d  origin=(%.0f, %.0f)  %@  id=%u",
                index + 1,
                display.name,
                Int(f.width),
                Int(f.height),
                f.minX,
                f.minY,
                display.isMain ? "主显示器" : "        ",
                display.id
            ))
        }

        if let location = MouseManager.shared.currentLocation() {
            print(String(format: "鼠标位置: (%.0f, %.0f)", location.x, location.y))
        } else {
            print("鼠标位置: 无法读取")
        }

        guard let current = MouseManager.shared.currentDisplay() else {
            print("当前显示器: 无法确定")
            return
        }
        print("当前显示器: \(current.name)")

        for direction in [DisplayManager.Direction.left, DisplayManager.Direction.right] {
            let label = direction == .left ? "左侧" : "右侧"
            guard let target = DisplayManager.shared.neighbor(of: current, direction: direction) else {
                print("\(label)显示器: 无")
                continue
            }
            let point = MouseManager.shared.targetPoint(in: target)
            print(String(
                format: "%@显示器: %@  →  目标坐标 (%.0f, %.0f)",
                label,
                target.name,
                point.x,
                point.y
            ))
        }

        guard let argument else { return }

        print("--- 执行切换 ---")
        switch argument {
        case "left":
            SwitchCoordinator.shared.move(direction: .left)
        case "right":
            SwitchCoordinator.shared.move(direction: .right)
        default:
            if let id = UInt32(argument) {
                SwitchCoordinator.shared.move(to: CGDirectDisplayID(id))
            } else {
                print("无法识别的参数: \(argument)（可用 left / right / 显示器 ID）")
            }
        }

        if let location = MouseManager.shared.currentLocation() {
            print(String(format: "切换后鼠标位置: (%.0f, %.0f)", location.x, location.y))
        }
    }
}
