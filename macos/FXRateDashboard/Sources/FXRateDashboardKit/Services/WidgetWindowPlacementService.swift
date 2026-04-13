import AppKit
import Combine
import Foundation

@MainActor
public final class WidgetWindowPlacementService {
    private weak var window: NSWindow?
    private weak var viewModel: MainWidgetViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []

    public init() {}

    public func bind(window: NSWindow, to viewModel: MainWidgetViewModel) {
        guard self.window !== window else {
            return
        }

        cleanup()

        self.window = window
        self.viewModel = viewModel

        configure(window: window, viewModel: viewModel)
        bindViewModel(viewModel)
        restoreWindowFrameIfNeeded()
    }

    private func configure(window: NSWindow, viewModel: MainWidgetViewModel) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = !viewModel.isPositionLocked
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView])
        window.styleMask.insert(.borderless)
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.collectionBehavior = [.moveToActiveSpace]
        applyWindowMask(metrics: viewModel.metrics)
        applyMetrics(viewModel.metrics, animated: false)

        let notificationCenter = NotificationCenter.default
        observers.append(
            notificationCenter.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.persistCurrentOrigin()
                }
            }
        )
        observers.append(
            notificationCenter.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.viewModel?.setWindowVisible(true)
                }
            }
        )
    }

    private func bindViewModel(_ viewModel: MainWidgetViewModel) {
        viewModel.$isCompactMode
            .sink { [weak self] isCompactMode in
                Task { @MainActor [weak self] in
                    self?.applyMetrics(isCompactMode ? .compact : .full, animated: true)
                }
            }
            .store(in: &cancellables)

        viewModel.$isWindowVisible
            .sink { [weak self] isVisible in
                self?.setWindowVisible(isVisible)
            }
            .store(in: &cancellables)

        viewModel.$isPositionLocked
            .sink { [weak self] isLocked in
                self?.window?.isMovableByWindowBackground = !isLocked
            }
            .store(in: &cancellables)
    }

    private func restoreWindowFrameIfNeeded() {
        guard let window, let viewModel else {
            return
        }

        let size = viewModel.metrics.size
        if let x = viewModel.settings.windowOriginX, let y = viewModel.settings.windowOriginY {
            let contentRect = CGRect(origin: CGPoint(x: x, y: y), size: size)
            window.setFrame(window.frameRect(forContentRect: contentRect), display: true)
        } else {
            window.center()
            applyMetrics(viewModel.metrics, animated: false)
        }
    }

    private func applyMetrics(_ metrics: WidgetMetrics, animated: Bool) {
        guard let window else {
            return
        }

        applyWindowMask(metrics: metrics)

        let targetRect = targetFrame(
            for: metrics.size,
            currentFrame: window.frame,
            workArea: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame,
            window: window
        )
        window.minSize = metrics.size
        window.maxSize = metrics.size
        window.contentMinSize = metrics.size
        window.contentMaxSize = metrics.size
        window.setContentSize(metrics.size)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetRect, display: true)
            }
        } else {
            window.setFrame(targetRect, display: true)
        }

        window.invalidateShadow()
    }

    private func targetFrame(for size: CGSize, currentFrame: CGRect, workArea: CGRect, window: NSWindow) -> CGRect {
        let origin = WindowPlacementHelper.calculateClampedTopLeft(
            workArea: workArea,
            currentBounds: currentFrame,
            targetSize: size
        )

        let contentRect = CGRect(origin: origin, size: size)
        return window.frameRect(forContentRect: contentRect)
    }

    private func setWindowVisible(_ isVisible: Bool) {
        guard let window else {
            return
        }

        if isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            window.orderOut(nil)
        }
    }

    private func persistCurrentOrigin() {
        guard let window, let viewModel else {
            return
        }

        viewModel.updateWindowPosition(x: window.frame.origin.x, y: window.frame.origin.y)
    }

    private func cleanup() {
        cancellables.removeAll()
        let notificationCenter = NotificationCenter.default
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    private func applyWindowMask(metrics: WidgetMetrics) {
        guard let window else {
            return
        }

        let radius = metrics.cornerRadius

        let views: [NSView?] = [
            window.contentView,
            window.contentViewController?.view,
            window.contentView?.superview
        ]

        views.forEach { view in
            view?.wantsLayer = true
            view?.layer?.cornerRadius = radius
            view?.layer?.cornerCurve = .continuous
            view?.layer?.masksToBounds = true
            view?.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
