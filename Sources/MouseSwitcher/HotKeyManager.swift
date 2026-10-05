import Foundation
import Carbon
import AppKit

/// 全局快捷键管理。
///
/// 使用 Carbon `RegisterEventHotKey` 注册真正的系统级热键，
/// 即使焦点在 Chrome / VS Code / Terminal / 全屏 App 中也能触发。
/// 不使用 NSMenu keyEquivalent 代替（那只在应用自身菜单内生效）。
final class HotKeyManager {

    enum Direction: String {
        case left
        case right
    }

    static let shared = HotKeyManager()

    /// 快捷键触发回调。
    var onHotKey: ((Direction) -> Void)?

    private var registeredRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var isRegistered = false

    private init() {}

    // MARK: - 注册

    /// 注册 Option + ← / Option + →。
    @discardableResult
    func register() -> Bool {
        guard !isRegistered else { return true }
        isRegistered = true

        installEventHandler()

        let codes: [(UInt32, UInt32, Direction)] = [
            (UInt32(kVK_LeftArrow), UInt32(optionKey), .left),
            (UInt32(kVK_RightArrow), UInt32(optionKey), .right)
        ]

        var success = true
        for (index, item) in codes.enumerated() {
            let (keyCode, modifiers, direction) = item
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            var reference: EventHotKeyRef?

            let status = RegisterEventHotKey(
                keyCode,
                modifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &reference
            )

            if status == noErr, let reference {
                registeredRefs[UInt32(index + 1)] = reference
                Self.directionMap[UInt32(index + 1)] = direction
                let arrow = (direction == .left) ? "←" : "→"
                Log.info("已注册快捷键 Option + " + arrow)
            } else {
                success = false
                Log.error("注册快捷键失败 (keyCode=\(keyCode), status=\(status))")
            }
        }

        return success
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandler
        )

        if status != noErr {
            Log.error("InstallEventHandler 失败：\(status)")
        }
    }

    func unregister() {
        for (_, reference) in registeredRefs {
            UnregisterEventHotKey(reference)
        }
        registeredRefs.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        isRegistered = false
    }

    // MARK: - C 回调桥接

    private static let signature: OSType = 0x4D535743 // 'MSWC'
    private static var directionMap: [UInt32: Direction] = [:]

    /// 由 Carbon 事件回调调用（全局 C 函数）。
    fileprivate static func handle(hotKeyID: UInt32) {
        guard let direction = directionMap[hotKeyID] else { return }
        let arrow = (direction == .left) ? "←" : "→"
        Log.info("HotKey: Option + " + arrow)
        DispatchQueue.main.async {
            HotKeyManager.shared.onHotKey?(direction)
        }
    }
}

/// Carbon 事件处理函数（C 函数指针）。
private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr else { return OSStatus(eventNotHandledErr) }

    HotKeyManager.handle(hotKeyID: UInt32(hotKeyID.id))
    return noErr
}
