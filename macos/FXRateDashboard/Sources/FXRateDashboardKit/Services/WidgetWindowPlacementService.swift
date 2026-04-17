import AppKit
import Combine
import Foundation

@MainActor
public final class WidgetWindowPlacementService {
    private let normalWindowAlpha: CGFloat = 1.0
    private let clickThroughWindowAlpha: CGFloat = 0.75
    private weak var window: NSWindow?
    private weak var viewModel: MainWidgetViewModel?
    private var cancellables = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var lastAppliedCompactMode: Bool?
    private var hasFinishedInitialPlacement = false
    private var isApplyingMetrics = false

    public init() {}

    public func persistCurrentWindowPosition() {
        persistCurrentOrigin()
    }

    public func bind(window: NSWindow, to viewModel: MainWidgetViewModel) {
        guard self.window !== window else {
            return
        }

        cleanup()

        self.window = window
        self.viewModel = viewModel
        self.lastAppliedCompactMode = viewModel.isCompactMode
        self.hasFinishedInitialPlacement = false

        configure(window: window, viewModel: viewModel)
        restoreWindowFrameIfNeeded()
        bindViewModel(viewModel)
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
        applyDesktopPinnedBehavior(for: window, isClickThroughEnabled: viewModel.isClickThroughEnabled)
        window.alphaValue = 0
        applyWindowMask(metrics: viewModel.metrics)
        applyMetrics(viewModel.metrics, animated: false)

        let notificationCenter = NotificationCenter.default
        observers.append(
            notificationCenter.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard !self.isApplyingMetrics else {
                        return
                    }
                    self.persistCurrentOrigin()
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
                    guard let self, let window else {
                        return
                    }

                    let previousMode = self.lastAppliedCompactMode ?? !isCompactMode
                    self.persistCurrentOrigin(forCompactMode: previousMode)
                    self.lastAppliedCompactMode = isCompactMode

                    let currentContentRect = window.contentRect(forFrameRect: window.frame)
                    let targetMetrics = isCompactMode ? WidgetMetrics.compact : WidgetMetrics.full
                    let anchoredOrigin = CGPoint(
                        x: currentContentRect.origin.x,
                        y: currentContentRect.maxY - targetMetrics.size.height
                    )

                    self.applyMetrics(
                        targetMetrics,
                        animated: true,
                        preferredOrigin: anchoredOrigin
                    )
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

        viewModel.$isClickThroughEnabled
            .sink { [weak self] isEnabled in
                guard let self, let window else {
                    return
                }

                self.applyDesktopPinnedBehavior(for: window, isClickThroughEnabled: isEnabled)
                if self.hasFinishedInitialPlacement {
                    window.alphaValue = self.targetWindowAlpha(isClickThroughEnabled: isEnabled)
                }
            }
            .store(in: &cancellables)
    }

    private func restoreWindowFrameIfNeeded() {
        guard let window, let viewModel else {
            return
        }

        if let origin = viewModel.storedWindowOrigin(forCompactMode: viewModel.isCompactMode) {
            applyMetrics(viewModel.metrics, animated: false, preferredOrigin: origin)
        } else {
            window.center()
            applyMetrics(viewModel.metrics, animated: false)
        }

        hasFinishedInitialPlacement = true
        window.alphaValue = targetWindowAlpha(isClickThroughEnabled: viewModel.isClickThroughEnabled)
        setWindowVisible(viewModel.isWindowVisible)
    }

    private func applyMetrics(_ metrics: WidgetMetrics, animated: Bool, preferredOrigin: CGPoint? = nil) {
        guard let window else {
            return
        }

        applyWindowMask(metrics: metrics)

        let targetRect = targetFrame(
            for: metrics.size,
            currentFrame: window.frame,
            workArea: window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? window.frame,
            window: window,
            preferredOrigin: preferredOrigin
        )
        window.minSize = metrics.size
        window.maxSize = metrics.size
        window.contentMinSize = metrics.size
        window.contentMaxSize = metrics.size

        if animated {
            isApplyingMetrics = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.6
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetRect, display: true)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
                self?.isApplyingMetrics = false
            }
        } else {
            isApplyingMetrics = true
            window.setFrame(targetRect, display: true)
            isApplyingMetrics = false
        }

        window.invalidateShadow()
    }

    private func targetFrame(
        for size: CGSize,
        currentFrame: CGRect,
        workArea: CGRect,
        window: NSWindow,
        preferredOrigin: CGPoint?
    ) -> CGRect {
        let origin: CGPoint

        if let preferredOrigin {
            origin = CGPoint(
                x: min(max(preferredOrigin.x, workArea.minX), workArea.maxX - size.width),
                y: min(max(preferredOrigin.y, workArea.minY), workArea.maxY - size.height)
            )
        } else {
            origin = WindowPlacementHelper.calculateClampedTopLeft(
                workArea: workArea,
                currentBounds: currentFrame,
                targetSize: size
            )
        }

        let contentRect = CGRect(origin: origin, size: size)
        return window.frameRect(forContentRect: contentRect)
    }

    private func setWindowVisible(_ isVisible: Bool) {
        guard let window else {
            return
        }

        guard hasFinishedInitialPlacement else {
            return
        }

        if isVisible {
            NSApp.unhide(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.hide(nil)
        }
    }

    private func persistCurrentOrigin(forCompactMode: Bool? = nil) {
        guard let window, let viewModel else {
            return
        }

        let contentOrigin = window.contentRect(forFrameRect: window.frame).origin
        viewModel.updateWindowPosition(
            x: contentOrigin.x,
            y: contentOrigin.y,
            forCompactMode: forCompactMode
        )
    }

    private func cleanup() {
        cancellables.removeAll()
        let notificationCenter = NotificationCenter.default
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    private func targetWindowAlpha(isClickThroughEnabled: Bool) -> CGFloat {
        isClickThroughEnabled ? clickThroughWindowAlpha : normalWindowAlpha
    }

    private func applyDesktopPinnedBehavior(for window: NSWindow, isClickThroughEnabled: Bool) {
        var behavior: NSWindow.CollectionBehavior = [.moveToActiveSpace]
        if isClickThroughEnabled {
            // Apple documents `.stationary` as staying visible and stationary
            // like the desktop window, which best matches the widget-like mode.
            behavior.insert(.stationary)
        }

        window.collectionBehavior = behavior
        window.ignoresMouseEvents = isClickThroughEnabled
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
