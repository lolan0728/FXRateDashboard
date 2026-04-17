import Combine
import Foundation

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public private(set) var toggleVisibilityText = "Hide Window"
    @Published public private(set) var toggleModeText = "Compact Mode"
    @Published public private(set) var isClickThroughEnabled = false

    private let mainWidgetViewModel: MainWidgetViewModel
    private var cancellables = Set<AnyCancellable>()

    public init(mainWidgetViewModel: MainWidgetViewModel) {
        self.mainWidgetViewModel = mainWidgetViewModel

        mainWidgetViewModel.$isWindowVisible
            .map { $0 ? "Hide Window" : "Show Window" }
            .assign(to: &$toggleVisibilityText)

        mainWidgetViewModel.$isCompactMode
            .map { $0 ? "Restore Full Mode" : "Compact Mode" }
            .assign(to: &$toggleModeText)

        mainWidgetViewModel.$isClickThroughEnabled
            .assign(to: &$isClickThroughEnabled)
    }

    public func toggleVisibility() {
        mainWidgetViewModel.setWindowVisible(!mainWidgetViewModel.isWindowVisible)
    }

    public func toggleCompactMode() {
        Task {
            await mainWidgetViewModel.toggleCompactMode()
        }
    }

    public func toggleClickThrough() {
        Task {
            await mainWidgetViewModel.toggleClickThrough()
        }
    }

    public func setClickThroughEnabled(_ isEnabled: Bool) {
        Task {
            await mainWidgetViewModel.setClickThroughEnabled(isEnabled)
        }
    }
}
