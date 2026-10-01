import AppKit
import SwiftUI

/// Developer tool for the README screenshots. Launched with
/// `TWENTYMINTRACK_SNAPSHOT=<directory>`, the app lays out its main
/// surfaces in off-screen windows (nothing appears on the display),
/// renders each one — title bar included — into `<directory>/<name>.png`
/// with a rounded, shadowed window frame, writes `done`, and quits.
enum SnapshotMode {
    static var outputPath: String? {
        ProcessInfo.processInfo.environment["TWENTYMINTRACK_SNAPSHOT"]
    }

    struct Shot {
        let name: String
        let title: String?
        let size: NSSize
        let view: AnyView
    }

    private static var windows: [NSWindow] = []

    static func present(_ shots: [Shot], to directory: String) {
        for (index, shot) in shots.enumerated() {
            let window = makeWindow(for: shot)
            window.setFrameOrigin(NSPoint(x: -20_000 - CGFloat(index) * 1_500, y: 200))
            window.orderFront(nil)
            windows.append(window)
        }
        // Give SwiftUI a moment to lay out and load before rendering.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            for (shot, window) in zip(shots, windows) {
                guard let png = render(window) else { continue }
                try? png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(shot.name).png"))
            }
            try? "done".write(toFile: directory + "/done", atomically: true, encoding: .utf8)
            exit(0)
        }
    }

    /// Window frame view → 2x bitmap, framed with rounded corners and a
    /// soft drop shadow (like a macOS window screenshot).
    private static func render(_ window: NSWindow) -> Data? {
        guard let content = window.contentView else { return nil }
        let view = content.superview ?? content
        let bounds = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        view.cacheDisplay(in: bounds, to: rep)
        let snapshot = NSImage(size: bounds.size)
        snapshot.addRepresentation(rep)

        let margin: CGFloat = 48
        let canvas = NSSize(width: bounds.width + margin * 2, height: bounds.height + margin * 2)
        guard let out = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * 2), pixelsHigh: Int(canvas.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        out.size = canvas
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        let frame = NSRect(x: margin, y: margin, width: bounds.width, height: bounds.height)
        let shape = NSBezierPath(roundedRect: frame, xRadius: 12, yRadius: 12)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 28
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor.windowBackgroundColor.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        shape.addClip()
        snapshot.draw(in: frame)
        NSColor.white.withAlphaComponent(0.12).setStroke()
        shape.lineWidth = 1
        shape.stroke()
        NSGraphicsContext.restoreGraphicsState()
        return out.representation(using: .png, properties: [:])
    }

    private static func makeWindow(for shot: Shot) -> NSWindow {
        let hosting = NSHostingView(rootView: shot.view)
        // Height 0 = size to the content's fitting height.
        var size = shot.size
        if size.height == 0 {
            hosting.frame.size = NSSize(width: size.width, height: 2_000)
            size.height = hosting.fittingSize.height
        }
        let rect = NSRect(origin: .zero, size: size)
        guard let title = shot.title else {
            // Popover look: borderless, framed by render().
            let window = OffscreenWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            window.contentView = hosting
            return window
        }
        let window = OffscreenWindow(contentRect: rect, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = title
        window.contentView = hosting
        return window
    }
}

/// Skips AppKit's on-screen constraint so the window can live off-screen.
private final class OffscreenWindow: NSWindow {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
