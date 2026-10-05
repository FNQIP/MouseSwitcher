import Foundation
import AppKit

// MARK: - 入口

// 关闭 stdout 缓冲，保证日志能实时出现在 Console / 终端里。
setvbuf(stdout, nil, _IONBF, 0)

let arguments = Array(CommandLine.arguments.dropFirst())

// 调试开关：--diagnose / --move left|right
// 正常通过 open MouseSwitcher.app 启动时不会进入这里。
if let first = arguments.first {
    switch first {
    case "--diagnose", "-d":
        _ = NSApplication.shared
        Diagnostics.run(move: nil)
        exit(0)
    case "--move", "-m":
        _ = NSApplication.shared
        Diagnostics.run(move: arguments.count > 1 ? arguments[1] : nil)
        exit(0)
    case "--help", "-h":
        print("MouseSwitcher")
        print("  --diagnose          打印显示器拓扑与左右关系")
        print("  --move left|right   执行一次显示器切换")
        print("  --help              显示本帮助")
        exit(0)
    default:
        break
    }
}

let application = NSApplication.shared

// 菜单栏应用：不显示 Dock 图标。
application.setActivationPolicy(.accessory)

let delegate = AppDelegate.shared
application.delegate = delegate

Log.info("启动中…")
application.run()
