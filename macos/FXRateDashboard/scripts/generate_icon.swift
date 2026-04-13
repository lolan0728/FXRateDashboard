import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate_icon.swift <output-dir>\n", stderr)
    exit(1)
}

let outputDirectory = URL(fileURLWithPath: arguments[1], isDirectory: true)
let fileManager = FileManager.default
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let iconSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

let baseGreen = NSColor(calibratedRed: 0.63, green: 0.92, blue: 0.36, alpha: 1)
let deepGreen = NSColor(calibratedRed: 0.08, green: 0.24, blue: 0.06, alpha: 1)
let warmWhite = NSColor(calibratedRed: 0.99, green: 0.99, blue: 0.97, alpha: 1)
let chartOrange = NSColor(calibratedRed: 0.90, green: 0.49, blue: 0.40, alpha: 1)
let border = NSColor(calibratedWhite: 0.86, alpha: 1)

for (size, name) in iconSizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: size, height: size)

    let outer = NSBezierPath(roundedRect: rect.insetBy(dx: CGFloat(size) * 0.04, dy: CGFloat(size) * 0.04), xRadius: CGFloat(size) * 0.23, yRadius: CGFloat(size) * 0.23)
    let gradient = NSGradient(colors: [warmWhite, NSColor.white])!
    gradient.draw(in: outer, angle: -90)
    border.setStroke()
    outer.lineWidth = max(1, CGFloat(size) * 0.012)
    outer.stroke()

    let pillRect = NSRect(x: CGFloat(size) * 0.13, y: CGFloat(size) * 0.72, width: CGFloat(size) * 0.44, height: CGFloat(size) * 0.14)
    let pill = NSBezierPath(roundedRect: pillRect, xRadius: pillRect.height / 2, yRadius: pillRect.height / 2)
    baseGreen.setFill()
    pill.fill()

    let chipRect = NSRect(x: CGFloat(size) * 0.70, y: CGFloat(size) * 0.74, width: CGFloat(size) * 0.16, height: CGFloat(size) * 0.11)
    let chip = NSBezierPath(roundedRect: chipRect, xRadius: chipRect.height / 2, yRadius: chipRect.height / 2)
    NSColor(calibratedWhite: 0.98, alpha: 0.98).setFill()
    chip.fill()
    border.setStroke()
    chip.lineWidth = max(1, CGFloat(size) * 0.008)
    chip.stroke()

    let rateFont = NSFont.systemFont(ofSize: CGFloat(size) * 0.22, weight: .semibold)
    let cnyFont = NSFont.systemFont(ofSize: CGFloat(size) * 0.09, weight: .semibold)
    let smallFont = NSFont.systemFont(ofSize: CGFloat(size) * 0.06, weight: .semibold)

    let rateText = NSAttributedString(
        string: "427.3",
        attributes: [
            .font: rateFont,
            .foregroundColor: deepGreen
        ]
    )
    rateText.draw(at: NSPoint(x: CGFloat(size) * 0.12, y: CGFloat(size) * 0.49))

    let cnyText = NSAttributedString(
        string: "CNY",
        attributes: [
            .font: cnyFont,
            .foregroundColor: deepGreen.withAlphaComponent(0.65)
        ]
    )
    cnyText.draw(at: NSPoint(x: CGFloat(size) * 0.73, y: CGFloat(size) * 0.545))

    let changeText = NSAttributedString(
        string: "-0.31%",
        attributes: [
            .font: smallFont,
            .foregroundColor: chartOrange
        ]
    )
    changeText.draw(at: NSPoint(x: CGFloat(size) * 0.13, y: CGFloat(size) * 0.41))

    let chartRect = NSRect(x: CGFloat(size) * 0.12, y: CGFloat(size) * 0.13, width: CGFloat(size) * 0.76, height: CGFloat(size) * 0.22)
    let chartPath = NSBezierPath(roundedRect: chartRect, xRadius: CGFloat(size) * 0.08, yRadius: CGFloat(size) * 0.08)
    NSColor(calibratedRed: 0.95, green: 0.97, blue: 0.91, alpha: 1).setFill()
    chartPath.fill()
    border.setStroke()
    chartPath.lineWidth = max(1, CGFloat(size) * 0.006)
    chartPath.stroke()

    let line = NSBezierPath()
    line.move(to: NSPoint(x: chartRect.minX + chartRect.width * 0.12, y: chartRect.minY + chartRect.height * 0.62))
    line.line(to: NSPoint(x: chartRect.minX + chartRect.width * 0.58, y: chartRect.minY + chartRect.height * 0.62))
    line.line(to: NSPoint(x: chartRect.minX + chartRect.width * 0.77, y: chartRect.minY + chartRect.height * 0.28))
    line.line(to: NSPoint(x: chartRect.minX + chartRect.width * 0.92, y: chartRect.minY + chartRect.height * 0.42))
    chartOrange.setStroke()
    line.lineWidth = max(1.5, CGFloat(size) * 0.018)
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    line.stroke()

    let dotRect = NSRect(
        x: chartRect.minX + chartRect.width * 0.90,
        y: chartRect.minY + chartRect.height * 0.39,
        width: CGFloat(size) * 0.05,
        height: CGFloat(size) * 0.05
    )
    let dot = NSBezierPath(ovalIn: dotRect)
    chartOrange.setFill()
    dot.fill()

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fputs("failed to render \(name)\n", stderr)
        exit(1)
    }

    try png.write(to: outputDirectory.appendingPathComponent(name))
}
