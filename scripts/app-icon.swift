// Draws Kasane's app icon, a MacBook seen from above with an external keyboard laid over its
// keys, into an .iconset directory for iconutil.
// Run through `just icon`: swift scripts/app-icon.swift <output.iconset>

import AppKit

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: app-icon.swift <output.iconset>\n".utf8))
    exit(EX_USAGE)
}
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])

// MARK: - Drawing helpers (the unit square is the 1024 px canvas)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
    CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ context: CGContext, _ path: CGPath, _ c: CGColor) {
    context.addPath(path)
    context.setFillColor(c)
    context.fillPath()
}

func verticalGradient(_ context: CGContext, _ path: CGPath, top: UInt32, bottom: UInt32, in r: CGRect) {
    context.saveGState()
    context.addPath(path)
    context.clip()
    guard let gradient = CGGradient(colorsSpace: nil, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])
    else { preconditionFailure("two sRGB colors make a gradient") }
    context.drawLinearGradient(
        gradient, start: CGPoint(x: r.midX, y: r.maxY), end: CGPoint(x: r.midX, y: r.minY), options: [])
    context.restoreGState()
}

/// Shadow offsets and blur are in device pixels, not in the scaled unit square, so they take the
/// icon's pixel size.
func withShadow(
    _ context: CGContext, pixels: CGFloat, dx: CGFloat, dy: CGFloat, blur: CGFloat, alpha: CGFloat, _ draw: () -> Void
) {
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: dx * pixels, height: dy * pixels), blur: blur * pixels, color: color(0x000000, alpha))
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    draw()
    context.endTransparencyLayer()
    context.restoreGState()
}

/// Rows of keys inside `r`. The bottom row has a space bar between three keys on each side.
func keys(_ context: CGContext, in r: CGRect, rows: Int, columns: Int, gap: CGFloat, radius: CGFloat, _ c: CGColor) {
    let width = (r.width - gap * CGFloat(columns + 1)) / CGFloat(columns)
    let height = (r.height - gap * CGFloat(rows + 1)) / CGFloat(rows)
    func key(column: Int, y: CGFloat) -> CGRect {
        CGRect(x: r.minX + gap + CGFloat(column) * (width + gap), y: y, width: width, height: height)
    }
    for row in 0..<rows {
        let y = r.minY + gap + CGFloat(row) * (height + gap)
        guard row == 0 else {
            for column in 0..<columns { fill(context, rounded(key(column: column, y: y), radius), c) }
            continue
        }
        for column in [0, 1, 2, columns - 3, columns - 2, columns - 1] {
            fill(context, rounded(key(column: column, y: y), radius), c)
        }
        fill(context, rounded(key(column: 3, y: y).union(key(column: columns - 4, y: y)), radius), c)
    }
}

// MARK: - The icon

func drawIcon(_ context: CGContext, pixels: CGFloat) {
    // The macOS icon grid: an 824 px rounded square centred on the 1024 px canvas.
    let body = rect(100.0 / 1024, 100.0 / 1024, 924.0 / 1024, 924.0 / 1024)
    let bodyPath = rounded(body, 185.0 / 1024)
    withShadow(context, pixels: pixels, dx: 0, dy: -0.008, blur: 0.025, alpha: 0.28) {
        fill(context, bodyPath, color(0xD9E0EC))
    }
    verticalGradient(context, bodyPath, top: 0xF4F7FC, bottom: 0xD9E0EC, in: body)

    // The MacBook: aluminium deck, trackpad, and the built-in keys.
    let deck = rect(0.16, 0.24, 0.84, 0.72)
    withShadow(context, pixels: pixels, dx: 0, dy: -0.008, blur: 0.02, alpha: 0.22) {
        verticalGradient(context, rounded(deck, 0.045), top: 0xE6E9EE, bottom: 0xC9CED6, in: deck)
    }
    let trackpad = rounded(rect(0.385, 0.28, 0.615, 0.43), 0.02)
    fill(context, trackpad, color(0xD3D7DE))
    context.addPath(trackpad)
    context.setStrokeColor(color(0xB3B9C3))
    context.setLineWidth(0.004)
    context.strokePath()
    keys(context, in: rect(0.21, 0.46, 0.79, 0.68), rows: 5, columns: 12, gap: 0.007, radius: 0.005, color(0x2F3238))

    // The external keyboard, laid slightly askew over the built-in keys.
    context.saveGState()
    context.translateBy(x: 0.5, y: 0.575)
    context.rotate(by: -0.05)
    context.translateBy(x: -0.5, y: -0.575)
    let external = rect(0.18, 0.455, 0.82, 0.695)
    withShadow(context, pixels: pixels, dx: 0.008, dy: -0.016, blur: 0.035, alpha: 0.38) {
        fill(context, rounded(external, 0.03), color(0x273554))
    }
    keys(
        context, in: external.insetBy(dx: 0.016, dy: 0.016), rows: 5, columns: 12, gap: 0.007, radius: 0.005,
        color(0xE8ECF3))
    context.restoreGState()
}

/// Draws at exact pixel sizes: NSImage.lockFocus would follow the screen's backing scale.
func png(pixels: Int) -> Data {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let graphics = NSGraphicsContext(bitmapImageRep: rep)
    else { preconditionFailure("cannot make a \(pixels) px bitmap") }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.cgContext.scaleBy(x: CGFloat(pixels), y: CGFloat(pixels))
    drawIcon(graphics.cgContext, pixels: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        preconditionFailure("cannot encode the \(pixels) px icon as PNG")
    }
    return data
}

// The file names iconutil expects, each with its size in pixels.
let sizes: [(String, Int)] = [16, 32, 128, 256, 512].flatMap { points in
    [("icon_\(points)x\(points).png", points), ("icon_\(points)x\(points)@2x.png", points * 2)]
}
do {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    for (name, pixels) in sizes {
        try png(pixels: pixels).write(to: outputDirectory.appendingPathComponent(name))
    }
} catch {
    FileHandle.standardError.write(Data("app-icon.swift: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
