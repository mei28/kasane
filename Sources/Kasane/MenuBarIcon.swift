import AppKit

/// The menu bar icon: an external keyboard laid over the built-in one, seen from above. It is a
/// template image, so the menu bar tints it for its light or dark appearance.
enum MenuBarIcon {
    enum State {
        /// The built-in keyboard works.
        case off
        /// The built-in keyboard is blocked: the external keyboard is filled, the built-in faded.
        case on
        /// kasane ignores its triggers: the whole icon is faded.
        case paused
        /// Something keeps kasane from working: an exclamation mark sits on the corner.
        case warning
    }

    static func image(_ state: State) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.scaleBy(x: bounds.width, y: bounds.height)
            faded(context, state == .paused ? 0.4 : 1) { drawKeyboards(context, blocked: state == .on) }
            if state == .warning { drawExclamationBadge(context) }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Kasane"
        return image
    }

    // The drawing works in a unit square; the menu bar draws it 18 pt wide.
    private static let line: CGFloat = 1.5 / 18
    private static let builtIn = CGRect(x: 0.24, y: 0.12, width: 0.74, height: 0.44)
    private static let external = CGRect(x: 0.02, y: 0.40, width: 0.74, height: 0.46)

    private static func drawKeyboards(_ context: CGContext, blocked: Bool) {
        faded(context, blocked ? 0.35 : 1) { stroke(context, outline(builtIn)) }
        // Clear a margin around the external keyboard so the built-in one passes under it.
        clear(context) { fill(context, rounded(external.insetBy(dx: -line, dy: -line), 0.1)) }
        let keyArea = external.insetBy(dx: 0.12, dy: 0.11)
        if blocked {
            fill(context, rounded(external, 0.08))
            clear(context) { drawKeys(context, in: keyArea) }
        } else {
            stroke(context, outline(external))
            drawKeys(context, in: keyArea)
        }
    }

    /// Four keys over a space bar with a key on each side.
    private static func drawKeys(_ context: CGContext, in area: CGRect) {
        let gap: CGFloat = 0.035
        let width = (area.width - gap * 5) / 4
        let height = (area.height - gap * 3) / 2
        let top = area.minY + gap * 2 + height
        for column in 0..<4 {
            let x = area.minX + gap + CGFloat(column) * (width + gap)
            fill(context, rounded(CGRect(x: x, y: top, width: width, height: height), 0.015))
        }
        let bottom = area.minY + gap
        let spaceBar = CGRect(
            x: area.minX + gap * 2 + width, y: bottom, width: area.width - gap * 4 - width * 2, height: height)
        fill(context, rounded(CGRect(x: area.minX + gap, y: bottom, width: width, height: height), 0.015))
        fill(context, rounded(spaceBar, 0.015))
        fill(context, rounded(CGRect(x: spaceBar.maxX + gap, y: bottom, width: width, height: height), 0.015))
    }

    private static func drawExclamationBadge(_ context: CGContext) {
        let center = CGPoint(x: 0.80, y: 0.20)
        func circle(_ radius: CGFloat) -> CGPath {
            CGPath(
                ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2),
                transform: nil)
        }
        clear(context) { fill(context, circle(0.26)) }
        fill(context, circle(0.20))
        clear(context) {
            fill(context, rounded(CGRect(x: center.x - 0.03, y: center.y - 0.02, width: 0.06, height: 0.16), 0.03))
            fill(context, CGPath(
                ellipseIn: CGRect(x: center.x - 0.032, y: center.y - 0.13, width: 0.064, height: 0.064),
                transform: nil))
        }
    }

    // MARK: - Drawing helpers

    private static func rounded(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// A rounded outline whose stroke stays inside `rect`.
    private static func outline(_ rect: CGRect) -> CGPath {
        rounded(rect.insetBy(dx: line / 2, dy: line / 2), 0.08)
    }

    private static func fill(_ context: CGContext, _ path: CGPath) {
        context.addPath(path)
        context.setFillColor(.black)
        context.fillPath()
    }

    private static func stroke(_ context: CGContext, _ path: CGPath) {
        context.addPath(path)
        context.setStrokeColor(.black)
        context.setLineWidth(line)
        context.strokePath()
    }

    /// Erases what `draw` paints instead of painting it.
    private static func clear(_ context: CGContext, _ draw: () -> Void) {
        context.saveGState()
        context.setBlendMode(.clear)
        draw()
        context.restoreGState()
    }

    private static func faded(_ context: CGContext, _ alpha: CGFloat, _ draw: () -> Void) {
        context.saveGState()
        context.setAlpha(alpha)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        draw()
        context.endTransparencyLayer()
        context.restoreGState()
    }
}
