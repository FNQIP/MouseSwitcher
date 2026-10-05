import Foundation

/// 轻量设置存储（UserDefaults）。第一阶段只保留必要项。
final class SettingsManager {

    static let shared = SettingsManager()

    private let defaults: UserDefaults

    private enum Key {
        static let preserveRelativePosition = "preserveRelativePosition"
        static let wrapAround = "wrapAround"
        static let logEnabled = "logEnabled"
    }

    private init() {
        // 在 App Bundle 中运行时直接使用 standard（即 com.local.MouseSwitcher）。
        defaults = .standard
        defaults.register(defaults: [
            Key.preserveRelativePosition: true,
            Key.wrapAround: true,
            Key.logEnabled: true
        ])
    }

    /// 切换显示器时是否保持鼠标相对位置（默认开启）。
    var preserveRelativePosition: Bool {
        get { defaults.bool(forKey: Key.preserveRelativePosition) }
        set { defaults.set(newValue, forKey: Key.preserveRelativePosition) }
    }

    /// 走到最左 / 最右时是否循环到另一端（默认开启）。
    /// 开启后任意一个方向键都可以持续切换到所有显示器。
    var wrapAround: Bool {
        get { defaults.bool(forKey: Key.wrapAround) }
        set { defaults.set(newValue, forKey: Key.wrapAround) }
    }

    /// 是否输出运行日志。
    var logEnabled: Bool {
        get { defaults.bool(forKey: Key.logEnabled) }
        set { defaults.set(newValue, forKey: Key.logEnabled) }
    }
}
