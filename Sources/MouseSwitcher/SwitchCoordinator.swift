import Foundation
import CoreGraphics

/// 把「快捷键 / 菜单点击」和「显示器查找 + 鼠标移动」串起来的协调层。
final class SwitchCoordinator {

    static let shared = SwitchCoordinator()

    private init() {}

    /// 按方向切换。单显示器时静默不做任何事。
    /// 开启循环后，走到最左 / 最右会绕回另一端。
    func move(direction: DisplayManager.Direction) {
        let displays = DisplayManager.shared.displays
        guard displays.count > 1 else {
            Log.info("仅有一个显示器，忽略切换")
            return
        }

        guard let current = MouseManager.shared.currentDisplay() else {
            Log.warn("无法确定鼠标当前所在显示器")
            return
        }

        Log.info("Mouse display: \(current.name)")

        let isLeft = (direction == .left)
        let labelCN = isLeft ? "左侧" : "右侧"
        let labelEN = isLeft ? "Left" : "Right"

        guard let target = DisplayManager.shared.neighbor(of: current, direction: direction) else {
            Log.info(labelCN + "没有可用显示器（已关闭循环）")
            return
        }

        Log.info(labelEN + " display: \(target.name)")
        MouseManager.shared.move(to: target)
    }

    /// 直接跳到指定显示器。
    func move(to displayID: CGDirectDisplayID) {
        guard let target = DisplayManager.shared.display(id: displayID) else {
            Log.warn("目标显示器不存在（可能已拔出）")
            return
        }
        MouseManager.shared.move(to: target)
    }
}
