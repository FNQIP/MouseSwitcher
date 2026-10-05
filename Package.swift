// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MouseSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MouseSwitcher",
            path: "Sources/MouseSwitcher"
        )
    ],
    // AppKit 大量 API 依赖主线程，这里使用 Swift 5 语言模式，
    // 避免把 AppKit 的主线程隔离问题全部升级为编译错误。
    swiftLanguageModes: [.v5]
)
