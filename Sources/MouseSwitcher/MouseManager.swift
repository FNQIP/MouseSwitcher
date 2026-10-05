import Foundation
import CoreGraphics
import AppKit

/// 负责读取鼠标位置、判断所在显示器、以及移动鼠标。
///
/// 全部使用 macOS 官方 CoreGraphics API，不使用 AppleScript / shell / 第三方工具。
final class MouseManager {

    static let shared = MouseManager()

    private init() {}

    // MARK: - 读取位置

    /// 当前鼠标位置（Quartz 全局显示坐标：原点在主显示器左上角，Y 轴向下，单位 point）。
    /// 与 `CGDisplayBounds` 完全同一坐标系。
    func currentLocation() -> CGPoint? {
        guard let event = CGEvent(source: nil) else {
            // 极端情况下退化到 NSScreen 坐标换算。
            return fallbackLocation()
        }
        return event.location
    }

    private func fallbackLocation() -> CGPoint? {
        let nsPoint = NSEvent.mouseLocation
        guard let main = NSScreen.screens.first(where: { $0.frame.origin == .zero })
                ?? NSScreen.main else { return nil }
        // NSScreen 坐标原点在主屏左下角、Y 轴向上，需要翻转。
        return CGPoint(x: nsPoint.x, y: main.frame.height - nsPoint.y)
    }

    /// 鼠标当前所在的显示器。
    func currentDisplay() -> DisplayInfo? {
        guard let point = currentLocation() else {
            Log.warn("无法读取鼠标位置")
            return nil
        }
        return DisplayManager.shared.display(containing: point)
    }

    // MARK: - 移动

    /// 将鼠标移动到指定显示器的对应位置。
    ///
    /// 默认保持相对位置：把当前鼠标在本显示器内的 0～1 比例映射到目标显示器。
    /// 用户关闭该选项时，移动到目标显示器中心。
    func move(to display: DisplayInfo) {
        guard PermissionManager.isTrusted() else {
            Log.warn("未获得辅助功能权限，无法移动鼠标")
            PermissionManager.notifyMissingPermission()
            return
        }

        let target = targetPoint(in: display)
        move(to: target, displayName: display.name)
    }

    /// 计算目标点：保持相对位置 或 中心点。
    func targetPoint(in display: DisplayInfo) -> CGPoint {
        let inset: CGFloat = 1.0

        guard SettingsManager.shared.preserveRelativePosition,
              let current = currentDisplay(),
              let mouse = currentLocation(),
              current.id != display.id,
              current.frame.width > 0,
              current.frame.height > 0 else {
            return CGPoint(x: display.frame.midX, y: display.frame.midY)
        }

        let relX = clamp((mouse.x - current.frame.minX) / current.frame.width, 0, 1)
        let relY = clamp((mouse.y - current.frame.minY) / current.frame.height, 0, 1)

        let x = display.frame.minX + relX * display.frame.width
        let y = display.frame.minY + relY * display.frame.height

        return CGPoint(
            x: clamp(x, display.frame.minX + inset, display.frame.maxX - inset),
            y: clamp(y, display.frame.minY + inset, display.frame.maxY - inset)
        )
    }

    /// 底层移动：CGWarpMouseCursorPosition + 补发 mouseMoved 事件，保证 App 能感知 hover。
    private func move(to point: CGPoint, displayName: String) {
        guard point.x.isFinite, point.y.isFinite else {
            Log.error("目标坐标非法，已忽略：\(point)")
            return
        }

        CGWarpMouseCursorPosition(point)

        if let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            event.post(tap: .cghidEventTap)
        }

        Log.info("Moving mouse to: (\(Int(point.x)), \(Int(point.y))) [\(displayName)]")
    }

    private func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
