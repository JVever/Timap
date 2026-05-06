import AppKit

/// Programmatic renderings of the Timap brand mark.
///
/// We draw the icon directly with `NSBezierPath` instead of bundling raster
/// PNGs because:
///   • the menu-bar status item needs a vector template that the system
///     auto-tints for light/dark menubar — `isTemplate=true` works best on
///     images that draw in plain `NSColor.black`;
///   • the brand mark is just three rounded rectangles plus an outer rounded
///     frame, so the geometry is trivial to express in code and stays crisp
///     at every DPI without shipping multiple PNGs.
///
/// Geometry follows the brand-kit spec: a 1024×1024 viewBox with the framed
/// menubar variant (`logo-menubar-framed.svg`).
enum BrandIcon {
    /// Standard macOS menubar icon size in points. The system gives the
    /// status item room for ~18×18 inside the 22pt-tall menubar.
    static let menubarSize: CGFloat = 18

    /// Framed menubar template: rounded-square outline + three bars in
    /// `currentColor`. Returns a template image so AppKit handles tinting.
    static func makeMenubarTemplate() -> NSImage {
        let size = NSSize(width: menubarSize, height: menubarSize)
        let image = NSImage(size: size, flipped: true) { rect in
            drawFramedLogo(in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Timap"
        return image
    }

    private static func drawFramedLogo(in rect: NSRect) {
        let s = rect.width / 1024.0

        NSColor.black.setFill()
        NSColor.black.setStroke()

        // Outer frame. SVG default stroke is centered on the path, so we
        // pass the unmodified path bounds and set lineWidth — the visible
        // stroke extends 28*s outside the rect, which lands the outer edge
        // 28*s from the canvas edge (matches the SVG).
        let frameRect = NSRect(x: 56*s, y: 56*s, width: 912*s, height: 912*s)
        let frame = NSBezierPath(roundedRect: frameRect, xRadius: 220*s, yRadius: 220*s)
        frame.lineWidth = 56 * s
        frame.stroke()

        // Three bars: top (intersection), middle (city A), bottom (city B).
        let bars: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat)] = [
            (420, 251, 220, 114, 17.1),
            (160, 455, 500, 114, 17.1),
            (420, 659, 480, 114, 17.1)
        ]
        for b in bars {
            let r = NSRect(x: b.x*s, y: b.y*s, width: b.w*s, height: b.h*s)
            NSBezierPath(roundedRect: r, xRadius: b.r*s, yRadius: b.r*s).fill()
        }
    }
}
