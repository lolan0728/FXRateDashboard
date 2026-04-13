import SwiftUI

public struct MenuBarMenuView: View {
    @ObservedObject private var viewModel: MenuBarViewModel
    private let openSettings: () -> Void
    private let quitApplication: () -> Void

    public init(
        viewModel: MenuBarViewModel,
        openSettings: @escaping () -> Void,
        quitApplication: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.openSettings = openSettings
        self.quitApplication = quitApplication
    }

    public var body: some View {
        Button(viewModel.toggleVisibilityText) {
            viewModel.toggleVisibility()
        }

        Button(viewModel.toggleModeText) {
            viewModel.toggleCompactMode()
        }

        Button("Settings") {
            openSettings()
        }

        Divider()

        Button("Quit") {
            quitApplication()
        }
    }
}
