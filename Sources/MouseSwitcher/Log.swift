import Foundation

/// 极简日志器。只在关键事件发生时打印，不做高频轮询输出。
enum Log {
    static let prefix = "[MouseSwitcher]"

    static func info(_ message: String) {
        print("\(prefix) \(message)")
    }

    static func warn(_ message: String) {
        print("\(prefix) ⚠️ \(message)")
    }

    static func error(_ message: String) {
        print("\(prefix) ❌ \(message)")
    }
}
