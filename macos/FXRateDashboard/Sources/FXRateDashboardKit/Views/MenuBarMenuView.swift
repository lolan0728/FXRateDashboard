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
        Button {
            viewModel.toggleVisibility()
        } label: {
            Label(viewModel.toggleVisibilityText, systemImage: "eye.slash")
        }

        Button {
            viewModel.toggleCompactMode()
        } label: {
            Label(viewModel.toggleModeText, systemImage: "arrow.up.left.and.arrow.down.right")
        }

        Toggle(
            isOn: Binding(
                get: { viewModel.isClickThroughEnabled },
                set: { viewModel.setClickThroughEnabled($0) }
            )
        ) {
            Text("Click Through")
        }

        Button {
            openSettings()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Divider()

        Button {
            quitApplication()
        } label: {
            Label("Quit", systemImage: "xmark.square")
        }
    }
}
