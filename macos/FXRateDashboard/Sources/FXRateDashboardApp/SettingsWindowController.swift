import AppKit
import FXRateDashboardKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private static let windowSize = NSSize(width: 392, height: 474)

    private weak var bootstrap: AppBootstrap?
    private var window: NSWindow?

    func show(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
        bootstrap.prepareSettingsViewModel()

        if let window {
            refreshContent(with: bootstrap, in: window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            clearInitialFocus(in: window)
            return
        }

        let window = buildWindow(with: bootstrap)
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        clearInitialFocus(in: window)
    }

    func closeWindow() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
        window = nil
    }

    private func buildWindow(with bootstrap: AppBootstrap) -> NSWindow {
        let rect = NSRect(origin: .zero, size: Self.windowSize)
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.delegate = self
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.minSize = Self.windowSize
        window.maxSize = Self.windowSize
        window.contentMinSize = Self.windowSize
        window.contentMaxSize = Self.windowSize
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.center()

        refreshContent(with: bootstrap, in: window)
        applyRoundedWindowMask(to: window)
        return window
    }

    private func refreshContent(with bootstrap: AppBootstrap, in window: NSWindow) {
        let rootView = SettingsView(
            viewModel: bootstrap.settingsViewModel,
            onSave: {
                await bootstrap.saveSettings()
            },
            onClose: { [weak self] in
                self?.closeWindow()
            }
        )

        let hostingController = NSHostingController(rootView: rootView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentViewController = hostingController
        window.setContentSize(Self.windowSize)
        applyRoundedWindowMask(to: window)
    }

    private func applyRoundedWindowMask(to window: NSWindow) {
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 30
        window.contentView?.layer?.masksToBounds = true
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func clearInitialFocus(in window: NSWindow) {
        DispatchQueue.main.async { [weak window] in
            window?.makeFirstResponder(nil)
        }
    }
}
