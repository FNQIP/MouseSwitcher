import Foundation
import AppKit
import CoreGraphics

/// 单个显示器的信息。
///
/// `frame` 使用 Quartz 全局显示坐标：
/// 主显示器原点为 (0, 0)，Y 轴向下增长，单位为 **点（point）**，
/// 因此 Retina / 非 Retina 混用无需额外换算。
struct DisplayInfo {
    let id: CGDirectDisplayID
    let frame: CGRect
    let isMain: Bool
    let name: String

    var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    /// 逻辑分辨率（点）
    var size: CGSize {
        frame.size
    }
}

/// 负责显示器枚举、空间关系计算以及热插拔监听。
final class DisplayManager {

    static let shared = DisplayManager()

    /// 当前所有在线显示器，按 minX 从左到右排序。
    private(set) var displays: [DisplayInfo] = []

    /// 显示器发生变化时的回调（始终在主线程触发）。
    var onChange: (() -> Void)?

    private var didRegisterCallback = false

    private init() {}

    // MARK: - 枚举

    /// 重新检测所有显示器。线程安全，可在任意线程调用。
    @discardableResult
    func refresh() -> [DisplayInfo] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else {
            Log.error("CGGetActiveDisplayList 获取数量失败")
            return displays
        }

        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            Log.error("CGGetActiveDisplayList 获取列表失败")
            return displays
        }

        let names = Self.displayNames()
        let mainID = CGMainDisplayID()

        var seen = Set<CGDirectDisplayID>()
        var result: [DisplayInfo] = []

        for rawID in ids where rawID != kCGNullDirectDisplay {
            // 镜像模式下同一个显示器可能重复出现，去重。
            if seen.contains(rawID) { continue }
            seen.insert(rawID)

            let bounds = CGDisplayBounds(rawID)
            guard bounds.width > 0, bounds.height > 0 else { continue }

            let name = names[rawID] ?? Self.fallbackName(for: bounds)
            let info = DisplayInfo(
                id: rawID,
                frame: bounds,
                isMain: rawID == mainID,
                name: name
            )
            result.append(info)
        }

        // 按空间位置排序：先左后右，同一列时按上到下。
        result.sort { a, b in
            if abs(a.frame.minX - b.frame.minX) > 1 {
                return a.frame.minX < b.frame.minX
            }
            return a.frame.minY < b.frame.minY
        }

        // 名称兜底编号（API 取不到名称时）
        result = result.enumerated().map { index, info in
            var copy = info
            if info.name.isEmpty {
                copy = DisplayInfo(
                    id: info.id,
                    frame: info.frame,
                    isMain: info.isMain,
                    name: "Display \(index + 1)"
                )
            }
            return copy
        }

        displays = result
        return result
    }

    // MARK: - 名称

    /// 通过 NSScreen 获取系统本地化的显示器名称。
    /// 取不到时返回空字典，由调用方兜底，绝不因此崩溃。
    private static func displayNames() -> [CGDirectDisplayID: String] {
        var map: [CGDirectDisplayID: String] = [:]
        let key = NSDeviceDescriptionKey("NSScreenNumber")

        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[key] as? NSNumber else { continue }
            let id = CGDirectDisplayID(number.uint32Value)
            var name = ""
            if #available(macOS 10.15, *) {
                name = screen.localizedName
            }
            if name.isEmpty {
                name = fallbackName(for: screen.frame)
            }
            map[id] = name
        }
        return map
    }

    private static func fallbackName(for frame: CGRect) -> String {
        "Display \(Int(frame.width))×\(Int(frame.height))"
    }

    // MARK: - 查询

    /// 根据坐标判断鼠标当前位于哪个显示器。
    /// 找不到时退化为“最近的一个显示器”，保证不返回 nil 崩溃。
    func display(containing point: CGPoint) -> DisplayInfo? {
        guard !displays.isEmpty else { return nil }

        for display in displays {
            if display.frame.contains(point) {
                return display
            }
        }

        // 浮点误差 / 处于边界外时，取中心点距离最近的一个。
        return displays.min { a, b in
            distance(from: point, to: a.frame) < distance(from: point, to: b.frame)
        }
    }

    func display(id: CGDirectDisplayID) -> DisplayInfo? {
        displays.first { $0.id == id }
    }

    // MARK: - 左 / 右 空间关系

    /// 查找指定方向上的相邻显示器。
    ///
    /// 判定完全基于真实空间坐标（minX / maxX / minY / maxY），
    /// 不依赖 CGGetActiveDisplayList 的数组顺序。
    ///
    /// 打分规则：
    /// 1. 优先选择严格位于该方向（X 区间不重叠）的显示器；
    /// 2. 其中 Y 区间重叠越多越好（处理上下错位布局）；
    /// 3. 重叠相同时 X 方向间距越小越好；
    /// 4. 再相同则中心点距离越近越好。
    ///
    /// `wrap = true` 时，走到最左侧 / 最右侧会环绕到另一端，
    /// 因此可以一直按同一个方向循环切换。
    func neighbor(
        of current: DisplayInfo,
        direction: Direction,
        wrap: Bool = SettingsManager.shared.wrapAround
    ) -> DisplayInfo? {
        guard displays.count > 1 else {
            Log.info("仅有一个显示器，忽略切换请求")
            return nil
        }
        return Self.resolveNeighbor(of: current, among: displays, direction: direction, wrap: wrap)
    }

    enum Direction {
        case left
        case right
    }

    /// 纯函数版的空间关系求解，只依赖传入的显示器列表，便于独立验证。
    static func resolveNeighbor(
        of current: DisplayInfo,
        among all: [DisplayInfo],
        direction: Direction,
        wrap: Bool = true
    ) -> DisplayInfo? {
        guard all.count > 1 else { return nil }

        let others = all.filter { $0.id != current.id }

        let strict = others.filter { isStrictly($0, in: direction, of: current) }

        // 宽松模式：例如 B 在 A 的右上方但 X 区间有重叠。
        let candidates = strict.isEmpty
            ? others.filter { isGenerally($0, in: direction, of: current) }
            : strict

        guard !candidates.isEmpty else {
            // 该方向已经到头：开启循环时跳到反方向的最外侧显示器。
            guard wrap else { return nil }
            return Self.oppositeEdge(in: others, direction: direction)
        }

        return candidates.min { a, b in
            score(of: a, from: current, direction: direction) < score(of: b, from: current, direction: direction)
        }
    }

    /// 环绕目标：向右到头 → 最左那台；向左到头 → 最右那台。
    static func oppositeEdge(in others: [DisplayInfo], direction: Direction) -> DisplayInfo? {
        guard !others.isEmpty else { return nil }
        switch direction {
        case .right:
            return others.min { $0.frame.minX < $1.frame.minX }
        case .left:
            return others.max { $0.frame.maxX < $1.frame.maxX }
        }
    }

    static func isStrictly(_ candidate: DisplayInfo, in direction: Direction, of current: DisplayInfo) -> Bool {
        switch direction {
        case .right:
            return candidate.frame.minX >= current.frame.maxX - tolerance
        case .left:
            return candidate.frame.maxX <= current.frame.minX + tolerance
        }
    }

    static func isGenerally(_ candidate: DisplayInfo, in direction: Direction, of current: DisplayInfo) -> Bool {
        switch direction {
        case .right:
            return candidate.center.x > current.center.x + tolerance
        case .left:
            return candidate.center.x < current.center.x - tolerance
        }
    }

    /// 分值越小越优先。
    static func score(of candidate: DisplayInfo, from current: DisplayInfo, direction: Direction) -> Double {
        let overlap = yOverlap(candidate.frame, current.frame)
        let maxOverlap = min(current.frame.height, candidate.frame.height)

        let gap: CGFloat
        switch direction {
        case .right: gap = max(0, candidate.frame.minX - current.frame.maxX)
        case .left:  gap = max(0, current.frame.minX - candidate.frame.maxX)
        }

        // 归一化重叠度：0（完全不重叠）～ 1（完全重叠）
        let overlapRatio = maxOverlap > 0 ? overlap / maxOverlap : 0
        let centerDistance = hypot(candidate.center.x - current.center.x,
                                   candidate.center.y - current.center.y)

        // 权重保证优先级：重叠 >> 间距 >> 中心距离
        return (1.0 - Double(overlapRatio)) * 1_000_000.0
             + Double(gap) * 1_000.0
             + Double(centerDistance)
    }

    static func yOverlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        max(0, min(a.maxY, b.maxY) - max(a.minY, b.minY))
    }

    func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    static let tolerance: CGFloat = 1.0

    // MARK: - 热插拔监听

    /// 注册显示器配置变化回调（显示器插拔、排列调整、分辨率/缩放变更、合盖开盖）。
    func registerReconfigurationCallback() {
        guard !didRegisterCallback else { return }
        didRegisterCallback = true

        CGDisplayRegisterReconfigurationCallback({ displayID, flags, userInfo in
            // 该回调在系统线程触发，不做任何 UI / 状态操作，只投递到主线程。
            DispatchQueue.main.async {
                DisplayManager.shared.handleReconfiguration(displayID: displayID)
            }
        }, nil)

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleReconfiguration(displayID: kCGNullDirectDisplay)
        }

        nc.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleReconfiguration(displayID: kCGNullDirectDisplay)
        }
    }

    private func handleReconfiguration(displayID: CGDirectDisplayID) {
        let before = displays.count
        refresh()
        let after = displays.count

        if before != after {
            Log.info("Display count: \(after)")
        } else {
            Log.info("显示器配置变化，已重新检测（\(after) 个显示器）")
        }
        onChange?()
    }
}
