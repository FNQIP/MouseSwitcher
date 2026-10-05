// MouseSwitcher 图标生成器
//
// 纯 CoreGraphics 矢量绘制，不依赖任何第三方库、不需要 Xcode。
//
// 用法：
//   swift Tools/make-icon.swift
//
// 产出：
//   build/iconset/                      —— 各尺寸 PNG（供 iconutil 使用）
//   build/MouseSwitcher.icns            —— 最终图标（会被复制进 App Bundle）
//   build/icon-preview.png              —— 1024px 预览图
//
// 设计说明：
//   沿用参考图的视觉语言（近黑圆角方块 + 浅蓝灰几何字形），
//   但把字形改为「两块显示器 + 贯穿其间的左右双向箭头」，直接表达
//   “鼠标在显示器之间切换” 这一核心功能。
//   所有元素均为纯几何图形，16px 下仍可辨识。

import Foundation
import CoreGraphics
import ImageIO
import CoreText

// MARK: - 设计常量（全部基于 1024×1024 设计稿，坐标为 y 轴向上）

private let designSize: CGFloat = 1024

/// macOS Big Sur 之后的图标网格：1024 画布中内容区为 824×824，圆角半径 185。
private let bodyInset: CGFloat = 100
private let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
private let bodyRadius: CGFloat = 185

private let ink = RGB(0xEA, 0xF2, 0xFC)        // 主字形颜色（近白冷调）
private let inkDim = RGB(0xD6, 0xE4, 0xF4)     // 次级描边
private let void = RGB(0x12, 0x14, 0x19)       // 字形外描边（与背景同色系）

private struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = CGFloat(r) / 255
        self.g = CGFloat(g) / 255
        self.b = CGFloat(b) / 255
    }
    func alpha(_ a: CGFloat) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    var color: CGColor { alpha(1) }
}

// MARK: - 绘制

private func drawIcon(in ctx: CGContext, size: CGFloat) {
    let scale = size / designSize
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: scale, y: scale)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // --- 1. 底板：圆角方块 + 自上而下的暗色渐变 ---
    let body = CGPath(
        roundedRect: bodyRect,
        cornerWidth: bodyRadius,
        cornerHeight: bodyRadius,
        transform: nil
    )

    ctx.saveGState()
    ctx.addPath(body)
    ctx.clip()

    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            RGB(0x33, 0x38, 0x44).color,   // 顶部稍亮
            RGB(0x1A, 0x1D, 0x24).color,
            RGB(0x0E, 0x10, 0x15).color    // 底部近黑
        ] as CFArray,
        locations: [0.0, 0.55, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 512, y: bodyRect.maxY),
        end: CGPoint(x: 512, y: bodyRect.minY),
        options: []
    )

    // 顶部柔光，让纯色底不显得死板
    let gloss = CGGradient(
        colorsSpace: colorSpace,
        colors: [RGB(0xFF, 0xFF, 0xFF).alpha(0.10), RGB(0xFF, 0xFF, 0xFF).alpha(0.0)] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawRadialGradient(
        gloss,
        startCenter: CGPoint(x: 512, y: 900),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 900),
        endRadius: 620,
        options: []
    )

    ctx.restoreGState()

    // 边缘细高光，模拟金属倒角
    ctx.saveGState()
    ctx.addPath(body)
    ctx.setStrokeColor(RGB(0xFF, 0xFF, 0xFF).alpha(0.09))
    ctx.setLineWidth(3)
    ctx.strokePath()
    ctx.restoreGState()

    // --- 2. 两块显示器 ---
    // 两块屏之间留出足够空隙，小尺寸下才不会糊成一团。
    let paneSize: CGFloat = 300
    let paneY: CGFloat = 512 - paneSize / 2      // 362 … 662
    let paneRadius: CGFloat = 66
    let paneStroke: CGFloat = 30

    let leftPane = CGRect(x: 168, y: paneY, width: paneSize, height: paneSize)
    let rightPane = CGRect(x: 556, y: paneY, width: paneSize, height: paneSize)

    // 左屏：填充淡淡的墨色，暗示「鼠标当前所在的显示器」
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: leftPane, cornerWidth: paneRadius, cornerHeight: paneRadius, transform: nil))
    ctx.setFillColor(inkDim.alpha(0.16))
    ctx.fillPath()
    ctx.restoreGState()

    // 左右屏描边
    for rect in [leftPane, rightPane] {
        let path = CGPath(roundedRect: rect, cornerWidth: paneRadius, cornerHeight: paneRadius, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(inkDim.alpha(0.92))
        ctx.setLineWidth(paneStroke)
        ctx.setLineJoin(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    // --- 3. 贯穿两屏的双向箭头 ---
    // 先用背景色描一圈粗边（吃掉箭头的凹陷角），再填充主色，
    // 这样箭头压在屏幕边框上依然清晰可辨。
    let arrow = doubleArrowPath(tipLeft: CGPoint(x: 348, y: 512), tipRight: CGPoint(x: 676, y: 512))

    ctx.saveGState()
    ctx.addPath(arrow)
    ctx.setStrokeColor(void.color)
    ctx.setLineWidth(26)
    ctx.setLineJoin(.round)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(arrow)
    ctx.setFillColor(ink.color)
    ctx.fillPath()
    ctx.restoreGState()
}

/// 双向箭头路径：中间横杠 + 左右两个三角头。
private func doubleArrowPath(
    tipLeft: CGPoint,
    tipRight: CGPoint,
    headDepth: CGFloat = 60,
    headHalf: CGFloat = 54,
    barHalf: CGFloat = 19
) -> CGPath {
    let y = tipLeft.y
    let path = CGMutablePath()
    path.move(to: CGPoint(x: tipLeft.x, y: y))
    path.addLine(to: CGPoint(x: tipLeft.x + headDepth, y: y + headHalf))
    path.addLine(to: CGPoint(x: tipLeft.x + headDepth, y: y + barHalf))
    path.addLine(to: CGPoint(x: tipRight.x - headDepth, y: y + barHalf))
    path.addLine(to: CGPoint(x: tipRight.x - headDepth, y: y + headHalf))
    path.addLine(to: CGPoint(x: tipRight.x, y: y))
    path.addLine(to: CGPoint(x: tipRight.x - headDepth, y: y - headHalf))
    path.addLine(to: CGPoint(x: tipRight.x - headDepth, y: y - barHalf))
    path.addLine(to: CGPoint(x: tipLeft.x + headDepth, y: y - barHalf))
    path.addLine(to: CGPoint(x: tipLeft.x + headDepth, y: y - headHalf))
    path.closeSubpath()
    return path
}

// MARK: - 菜单栏模板图（候选方案）

/// 菜单栏图标的候选方案。
///
/// 共同约束：模板图只有 alpha 通道，无法表现"深色底板 + 浅色字形"，
/// 因此菜单栏版本不再画底板，只保留字形；同时刻度必须比 App 图标粗，
/// 否则在 20 点上下会被抗锯齿吃掉。
/// 菜单栏图标的几何参数。
///
/// 设计坐标系宽度固定 1024（y 轴向上），高度按点尺寸比例推导；
/// 所有子元素都在这个坐标系里排布，换算成像素时统一缩放。
struct GlyphParams {
    var pointSize: CGSize
    /// 单块屏幕「可见」边长（含描边外扩部分）
    var screenVisible: CGFloat
    var screenStroke: CGFloat
    var screenRadius: CGFloat
    /// 画布两端留白
    var margin: CGFloat
    /// 双向箭头左右端点
    var tipLeft: CGFloat
    var tipRight: CGFloat
    var headDepth: CGFloat
    var headHalf: CGFloat
    var barHalf: CGFloat
    /// > 0 时在箭头周围掏一圈透明缝隙，让它与屏幕边框分离
    var halo: CGFloat
    /// 是否先铺 App 图标同款圆角底板，再把内部图形挖空
    var plate: Bool
}

enum MenuBarVariant: String, CaseIterable {
    /// 线上版本：小屏 + 长箭头（对照组）
    case current
    /// 放大屏幕，箭头两端顶到屏幕边框
    case attached
    /// 屏幕略收，把宽度让给箭头，让双向箭头成为主体
    case attachedWide
    /// 放大屏幕，箭头留在空隙内且与边框留出间隙
    case gapArrow
    /// 放大屏幕 + 箭头像 App 图标那样穿进屏幕（窄镂空）
    case pierce
    /// 保留 App 图标的圆角底板剪影，内部图形挖空
    case plate

    var label: String {
        switch self {
        case .current:  return "A 当前 20pt 方"
        case .attached: return "B 大屏+贴身箭头 26×12"
        case .attachedWide: return "F 收屏+宽箭头 26×12"
        case .gapArrow: return "C 大屏+空隙箭头 26×12"
        case .pierce:   return "D 大屏+穿透箭头 26×12"
        case .plate:    return "E 圆角底板 20pt 方"
        }
    }

    var params: GlyphParams {
        switch self {
        case .current:
            return GlyphParams(
                pointSize: CGSize(width: 20, height: 20),
                screenVisible: 280, screenStroke: 92, screenRadius: 30, margin: 24,
                tipLeft: 316, tipRight: 708, headDepth: 92, headHalf: 82, barHalf: 45,
                halo: 0, plate: false
            )
        case .attached:
            return GlyphParams(
                pointSize: CGSize(width: 26, height: 12),
                screenVisible: 340, screenStroke: 64, screenRadius: 52, margin: 8,
                tipLeft: 366, tipRight: 658, headDepth: 79, headHalf: 69, barHalf: 30,
                halo: 0, plate: false
            )
        case .attachedWide:
            return GlyphParams(
                pointSize: CGSize(width: 26, height: 12),
                screenVisible: 310, screenStroke: 60, screenRadius: 46, margin: 8,
                tipLeft: 324, tipRight: 700, headDepth: 78, headHalf: 72, barHalf: 32,
                halo: 0, plate: false
            )
        case .gapArrow:
            return GlyphParams(
                pointSize: CGSize(width: 26, height: 12),
                screenVisible: 370, screenStroke: 64, screenRadius: 50, margin: 8,
                tipLeft: 390, tipRight: 634, headDepth: 66, headHalf: 60, barHalf: 28,
                halo: 0, plate: false
            )
        case .pierce:
            return GlyphParams(
                pointSize: CGSize(width: 26, height: 12),
                screenVisible: 420, screenStroke: 76, screenRadius: 52, margin: 8,
                tipLeft: 250, tipRight: 774, headDepth: 76, headHalf: 60, barHalf: 30,
                halo: 30, plate: false
            )
        case .plate:
            return GlyphParams(
                pointSize: CGSize(width: 20, height: 20),
                screenVisible: 380, screenStroke: 80, screenRadius: 62, margin: 72,
                tipLeft: 250, tipRight: 774, headDepth: 70, headHalf: 90, barHalf: 40,
                halo: 44, plate: true
            )
        }
    }

    /// 菜单栏中占用的逻辑尺寸（点）
    var pointSize: CGSize { params.pointSize }

    /// 设计稿高度：宽度固定 1024，高度按实际点尺寸比例推导
    var designHeight: CGFloat { 1024 * pointSize.height / pointSize.width }

    func draw(in ctx: CGContext, pixelSize: CGSize) {
        let p = params
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: pixelSize.width / 1024, y: pixelSize.height / designHeight)
        drawGlyph(ctx, p, designHeight: designHeight)
    }
}

/// 最终采用的方案。改这一行即可切换菜单栏图标。
let chosenMenuBarVariant: MenuBarVariant = .attached

private let mbInk = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)

/// 按参数绘制菜单栏图形。
private func drawGlyph(_ ctx: CGContext, _ p: GlyphParams, designHeight: CGFloat) {
    let cy = designHeight / 2
    let half = p.screenStroke / 2
    let side = p.screenVisible - p.screenStroke
    let y = cy - side / 2

    let left = CGRect(x: p.margin + half, y: y, width: side, height: side)
    let right = CGRect(x: 1024 - p.margin - half - side, y: y, width: side, height: side)

    let arrow = doubleArrowPath(
        tipLeft: CGPoint(x: p.tipLeft, y: cy),
        tipRight: CGPoint(x: p.tipRight, y: cy),
        headDepth: p.headDepth, headHalf: p.headHalf, barHalf: p.barHalf
    )

    // 底板方案：先铺满圆角方块，再把它当遮罩把内部图形挖空
    if p.plate {
        ctx.setFillColor(mbInk)
        ctx.addPath(CGPath(roundedRect: bodyRect, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil))
        ctx.fillPath()

        ctx.saveGState()
        ctx.setBlendMode(.clear)
        strokeScreens(ctx, left: left, right: right, radius: p.screenRadius, stroke: p.screenStroke)
        if p.halo > 0 {
            ctx.addPath(arrow)
            ctx.setLineWidth(p.halo)
            ctx.setLineJoin(.round)
            ctx.setLineCap(.round)
            ctx.strokePath()
        }
        ctx.addPath(arrow)
        ctx.fillPath()
        ctx.restoreGState()
        return
    }

    strokeScreens(ctx, left: left, right: right, radius: p.screenRadius, stroke: p.screenStroke)

    // 掏空箭头四周，让箭头与屏幕边框之间留出透明缝隙。
    // 宽度必须克制：过宽会把屏幕内侧边框整条擦掉，两块屏就成了破口的 []。
    if p.halo > 0 {
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.addPath(arrow)
        ctx.setLineWidth(p.halo)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()
        ctx.restoreGState()
    }

    ctx.setFillColor(mbInk)
    ctx.addPath(arrow)
    ctx.fillPath()
}

/// 画两块圆角矩形屏幕（描边）
private func strokeScreens(
    _ ctx: CGContext,
    left: CGRect,
    right: CGRect,
    radius: CGFloat,
    stroke: CGFloat
) {
    ctx.setStrokeColor(mbInk)
    ctx.setLineWidth(stroke)
    ctx.setLineJoin(.round)
    for rect in [left, right] {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.strokePath()
    }
}

// MARK: - 位图输出

private func render(size: Int) -> CGImage? {
    renderBitmap(width: size, height: size, drawer: drawIcon)
}

private func renderVariant(_ variant: MenuBarVariant, pointSize: CGSize) -> CGImage? {
    renderBitmap(
        width: Int(pointSize.width.rounded()),
        height: Int(pointSize.height.rounded()),
        drawer: { ctx, _ in variant.draw(in: ctx, pixelSize: pointSize) }
    )
}

private func renderBitmap(width: Int, height: Int, drawer: (CGContext, CGFloat) -> Void) -> CGImage? {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: max(1, width),
        height: max(1, height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    drawer(ctx, CGFloat(width))
    return ctx.makeImage()
}

private func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        FileHandle.standardError.write("无法创建 PNG: \(url.path)\n".data(using: .utf8)!)
        return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - 主流程

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let buildDir = root.appendingPathComponent("build")
// 注意：目录名必须以 .iconset 结尾，iconutil 才认。
let iconsetDir = buildDir.appendingPathComponent("MouseSwitcher.iconset")

try? FileManager.default.removeItem(at: iconsetDir)
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// iconutil 需要的标准 iconset 命名
let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    guard let image = render(size: variant.pixels) else {
        FileHandle.standardError.write("渲染失败: \(variant.name)\n".data(using: .utf8)!)
        exit(1)
    }
    writePNG(image, to: iconsetDir.appendingPathComponent(variant.name))
}

if let preview = render(size: 1024) {
    writePNG(preview, to: buildDir.appendingPathComponent("icon-preview.png"))
}

if let sheet = renderPreviewSheet() {
    writePNG(sheet, to: buildDir.appendingPathComponent("icon-preview-sheet.png"))
}

// 菜单栏模板图：按最终选定方案的逻辑尺寸生成 1x / 2x 两档。
// 两档都必须生成——代码里会把它们装进同一个 NSImage，
// 少了 @2x 就会在 Retina 屏上被放大，糊成一片。
let menuBarPointSize = chosenMenuBarVariant.pointSize
let assetsDir = root.appendingPathComponent("Resources/Assets")
try FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

for (name, scale) in [("menubar.png", 1), ("menubar@2x.png", 2)] {
    let pixels = CGSize(width: menuBarPointSize.width * CGFloat(scale),
                        height: menuBarPointSize.height * CGFloat(scale))
    guard let image = renderVariant(chosenMenuBarVariant, pointSize: pixels) else {
        FileHandle.standardError.write("菜单栏图标渲染失败: \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    writePNG(image, to: assetsDir.appendingPathComponent(name))
}

// 候选方案对照图：每个方案一行，列出放大预览、2x 实际尺寸、1x 实际尺寸。
// 浅底 / 深底各出一张，用于同时确认两种菜单栏下的可辨识度。
for (suffix, isDark) in [("", false), ("-dark", true)] {
    if let sheet = renderGlyphSheet(dark: isDark) {
        writePNG(sheet, to: buildDir.appendingPathComponent("menubar-preview\(suffix).png"))
    }
}

// 每个候选方案的 2x 位图单独落盘，便于拿去和真实菜单栏截图拼合对比
for variant in MenuBarVariant.allCases {
    let retina = CGSize(width: variant.pointSize.width * 2, height: variant.pointSize.height * 2)
    if let image = renderVariant(variant, pointSize: retina) {
        writePNG(image, to: buildDir.appendingPathComponent("variant-\(variant.rawValue)-2x.png"))
    }
}

print("✅ 已生成 \(variants.count) 个尺寸 → \(iconsetDir.path)")
print("   预览图 → \(buildDir.appendingPathComponent("icon-preview.png").path)")
print("   多尺寸检查图 → \(buildDir.appendingPathComponent("icon-preview-sheet.png").path)")
print("   菜单栏图标 → \(assetsDir.path)/menubar.png (+@2x)")
print("   菜单栏检查图 → \(buildDir.appendingPathComponent("menubar-preview.png").path)")

/// 菜单栏图标候选对照图。
///
/// 每个方案一行，三列分别是：
/// 1x 实际像素（放大 4 倍）、2x 实际像素（放大 4 倍）、矢量放大预览。
/// 放大统一用最近邻，保留真实像素，不美化。
private func renderGlyphSheet(dark: Bool) -> CGImage? {
    let rows = MenuBarVariant.allCases
    let rowHeight: CGFloat = 170
    let sheetW = 980
    let rowCount = CGFloat(rows.count)
    let sheetH = Int(rowHeight * rowCount + 70)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    guard let ctx = CGContext(
        data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let bg = dark ? RGB(0x1E, 0x1E, 0x20) : RGB(0xEF, 0xEF, 0xF2)
    let ink = dark ? RGB(0xFF, 0xFF, 0xFF) : RGB(0x10, 0x10, 0x14)
    let caption = dark ? RGB(0x9A, 0xA0, 0xA8) : RGB(0x55, 0x5A, 0x62)
    let rule = dark ? RGB(0x33, 0x33, 0x38) : RGB(0xD5, 0xD5, 0xDA)

    ctx.setFillColor(bg.color)
    ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))

    let sheetHeight = CGFloat(sheetH)

    // 列标题
    for (text, centerX) in [("1x 实际像素（放大 4 倍）", CGFloat(360)),
                            ("2x 实际像素（放大 4 倍）", CGFloat(620)),
                            ("矢量预览", CGFloat(860))] {
        drawText(ctx, text,
                 at: CGPoint(x: centerX - measureText(text, size: 14) / 2, y: sheetHeight - 28),
                 size: 14, color: caption.color)
    }

    for (index, variant) in rows.enumerated() {
        let top = sheetHeight - 50 - CGFloat(index) * rowHeight
        let centerY = top - rowHeight / 2 + 10

        // 分隔线
        ctx.setStrokeColor(rule.color)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: 16, y: top))
        ctx.addLine(to: CGPoint(x: CGFloat(sheetW) - 16, y: top))
        ctx.strokePath()

        let isChosen = variant == chosenMenuBarVariant
        drawText(ctx, variant.label,
                 at: CGPoint(x: 20, y: centerY - 7),
                 size: 15,
                 color: (isChosen ? (dark ? RGB(0x7F, 0xD1, 0xFF) : RGB(0x0A, 0x63, 0xC4)) : caption).color)
        if isChosen {
            drawText(ctx, "← 当前选用", at: CGPoint(x: 20, y: centerY - 27), size: 12,
                     color: (dark ? RGB(0x7F, 0xD1, 0xFF) : RGB(0x0A, 0x63, 0xC4)).color)
        }

        let pointSize = variant.pointSize

        // 1x 实际像素，放大 4 倍
        if let image = renderVariant(variant, pointSize: pointSize) {
            let w = pointSize.width * 4
            let h = pointSize.height * 4
            drawTemplated(ctx, image: image,
                          in: CGRect(x: 360 - w / 2, y: centerY - h / 2, width: w, height: h),
                          ink: ink)
        }

        // 2x 实际像素，放大 4 倍
        let retinaSize = CGSize(width: pointSize.width * 2, height: pointSize.height * 2)
        if let image = renderVariant(variant, pointSize: retinaSize) {
            let w = retinaSize.width * 4
            let h = retinaSize.height * 4
            drawTemplated(ctx, image: image,
                          in: CGRect(x: 620 - w / 2, y: centerY - h / 2, width: w, height: h),
                          ink: ink)
        }

        // 矢量放大预览（高插值，看设计本身）
        let previewSize = CGSize(width: pointSize.width * 7, height: pointSize.height * 7)
        if let image = renderVariant(variant, pointSize: previewSize) {
            let scale = min(200 / previewSize.width, rowHeight / previewSize.height)
            let w = previewSize.width * scale
            let h = previewSize.height * scale
            ctx.saveGState()
            ctx.interpolationQuality = .high
            ctx.clip(to: CGRect(x: 860 - w / 2, y: centerY - h / 2, width: w, height: h), mask: image)
            ctx.setFillColor(ink.color)
            ctx.fill(CGRect(x: 860 - w / 2, y: centerY - h / 2, width: w, height: h))
            ctx.restoreGState()
        }
    }

    return ctx.makeImage()
}

/// 简易文本绘制（CoreText，不依赖 AppKit）。
private func drawText(_ ctx: CGContext, _ text: String, at point: CGPoint, size: CGFloat, color: CGColor) {
    let font = CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color
    ]
    guard let attributed = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary) else { return }
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.saveGState()
    ctx.textPosition = point
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

private func measureText(_ text: String, size: CGFloat) -> CGFloat {
    let font = CTFontCreateWithName("HelveticaNeue" as CFString, size, nil)
    let attrs: [CFString: Any] = [kCTFontAttributeName: font]
    guard let attributed = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary) else { return 0 }
    return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil))
}

/// 把模板图当作遮罩，用指定颜色填充，并按最近邻放大（保留真实像素）。
private func drawTemplated(_ ctx: CGContext, image: CGImage, in rect: CGRect, ink: RGB) {
    ctx.saveGState()
    ctx.interpolationQuality = .none
    ctx.clip(to: rect, mask: image)
    ctx.setFillColor(ink.color)
    ctx.fill(rect)
    ctx.restoreGState()
}

/// 多尺寸检查图：把不同尺寸按最近邻放大到同一大小，
/// 便于肉眼确认小尺寸下的可辨识度。上排浅色背景，下排深色背景。
private func renderPreviewSheet() -> CGImage? {
    let sheetW = 840
    let sheetH = 520
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: sheetW, height: sheetH, bitsPerComponent: 8,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // y 轴向上：下方深色、上方浅色
    ctx.setFillColor(RGB(0x1C, 0x1C, 0x1E).color)
    ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH / 2))
    ctx.setFillColor(RGB(0xF2, 0xF2, 0xF5).color)
    ctx.fill(CGRect(x: 0, y: sheetH / 2, width: sheetW, height: sheetH / 2))

    let sizes = [256, 64, 32, 16]
    for (index, size) in sizes.enumerated() {
        guard let image = render(size: size) else { continue }
        let boxX = CGFloat(40 + index * 200)
        for rowY in [CGFloat(50), CGFloat(310)] {
            ctx.saveGState()
            ctx.interpolationQuality = .none          // 保留真实像素，不美化
            ctx.draw(image, in: CGRect(x: boxX, y: rowY, width: 160, height: 160))
            ctx.restoreGState()
        }
    }

    return ctx.makeImage()
}
