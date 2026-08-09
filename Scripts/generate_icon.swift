import AppKit

// Generates the app iconset: a clock ring split into three 20-minute
// segments, one highlighted. Usage: swift Scripts/generate_icon.swift <outDir>
let sizes: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2),
]
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for (points, scale) in sizes {
    let side = CGFloat(points * scale)
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let inset = side * 0.09
    let rect = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let background = NSBezierPath(roundedRect: rect, xRadius: side * 0.185, yRadius: side * 0.185)
    NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.32, alpha: 1).setFill()
    background.fill()

    let center = NSPoint(x: rect.midX, y: rect.midY)
    let radius = rect.width * 0.28
    let lineWidth = side * 0.055
    let gap: CGFloat = 10 // degrees between segments

    // Three 120° segments starting at 12 o'clock, clockwise.
    let segments: [(from: CGFloat, to: CGFloat, color: NSColor)] = [
        (90, -30, NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.5, alpha: 1)),
        (-30, -150, NSColor(calibratedWhite: 0.92, alpha: 0.45)),
        (-150, -270, NSColor(calibratedWhite: 0.92, alpha: 0.45)),
    ]
    for segment in segments {
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: center, radius: radius,
            startAngle: segment.from - gap / 2, endAngle: segment.to + gap / 2,
            clockwise: true
        )
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        segment.color.setStroke()
        arc.stroke()
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let name = scale == 1
        ? "icon_\(points)x\(points).png"
        : "icon_\(points)x\(points)@2x.png"
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("iconset written to \(outDir)")
