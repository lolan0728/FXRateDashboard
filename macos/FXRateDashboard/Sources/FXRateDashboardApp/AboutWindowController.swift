import AppKit

@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = buildWindow()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    private func buildWindow() -> NSWindow {
        let size = NSSize(width: 400, height: 280)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.title = "About FX Rate Dashboard"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1)
        window.center()
        window.minSize = size
        window.maxSize = size

        let contentView = AboutContentView(
            frame: NSRect(origin: .zero, size: size),
            iconImage: Self.generatedIconImage(size: 256),
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            githubURL: URL(string: "https://github.com/lolan0728/FXRateDashboard")!
        )
        window.contentView = contentView
        return window
    }

    private static func generatedIconImage(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let outerRect = rect.insetBy(dx: size * 0.06, dy: size * 0.06)
        let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: size * 0.22, yRadius: size * 0.22)
        NSColor(calibratedRed: 0.12, green: 0.29, blue: 0.02, alpha: 1).setFill()
        outerPath.fill()

        let innerRect = outerRect.insetBy(dx: size * 0.035, dy: size * 0.035)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: size * 0.19, yRadius: size * 0.19)
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.61, green: 0.91, blue: 0.40, alpha: 1),
            NSColor(calibratedRed: 0.39, green: 0.84, blue: 0.37, alpha: 1)
        ])!
        gradient.draw(in: innerPath, angle: -90)

        let line = NSBezierPath()
        line.move(to: NSPoint(x: size * 0.28, y: size * 0.34))
        line.line(to: NSPoint(x: size * 0.43, y: size * 0.52))
        line.line(to: NSPoint(x: size * 0.56, y: size * 0.46))
        line.line(to: NSPoint(x: size * 0.72, y: size * 0.66))
        line.line(to: NSPoint(x: size * 0.84, y: size * 0.58))
        line.lineCapStyle = .round
        line.lineJoinStyle = .round
        line.lineWidth = size * 0.085
        NSColor.white.setStroke()
        line.stroke()

        image.unlockFocus()
        return image
    }
}

@MainActor
private final class AboutContentView: NSView {
    private let githubURL: URL

    init(frame frameRect: NSRect, iconImage: NSImage, version: String, build: String, githubURL: URL) {
        self.githubURL = githubURL
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 1).cgColor

        let iconView = NSImageView()
        iconView.image = iconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = Self.makeLabel("FXRateDashboard", size: 21, weight: .bold, color: .white)
        let versionLabel = Self.makeLabel("Version \(version) (\(build))", size: 14, weight: .medium, color: NSColor.white.withAlphaComponent(0.74))
        let authorLabel = Self.makeLabel("Author: lolan Eos", size: 14, weight: .medium, color: NSColor.white.withAlphaComponent(0.74))

        let linkButton = NSButton(title: "https://github.com/lolan0728/FXRateDashboard", target: self, action: #selector(openGitHub))
        linkButton.isBordered = false
        linkButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        linkButton.contentTintColor = NSColor(calibratedRed: 0.52, green: 0.82, blue: 1, alpha: 1)
        linkButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [iconView, titleLabel, versionLabel, authorLabel, linkButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.distribution = .gravityAreas
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 92),
            iconView.heightAnchor.constraint(equalToConstant: 92),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            linkButton.widthAnchor.constraint(lessThanOrEqualToConstant: 340)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(githubURL)
    }

    private static func makeLabel(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
}
