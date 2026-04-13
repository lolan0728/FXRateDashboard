import SwiftUI

public struct MainWidgetWindowView: View {
    @ObservedObject private var viewModel: MainWidgetViewModel
    private let windowPlacementService: WidgetWindowPlacementService
    private let openSettings: () -> Void
    private let quitApplication: () -> Void

    public init(
        viewModel: MainWidgetViewModel,
        windowPlacementService: WidgetWindowPlacementService,
        openSettings: @escaping () -> Void,
        quitApplication: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.windowPlacementService = windowPlacementService
        self.openSettings = openSettings
        self.quitApplication = quitApplication
    }

    public var body: some View {
        let metrics = viewModel.metrics
        let widgetShape = RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)

        ZStack {
            widgetShape
                .fill(
                    LinearGradient(
                        colors: [
                            viewModel.panelBackgroundColor,
                            Color.white.opacity(viewModel.isOffline ? 0.76 : 0.96)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(ColorPalette.widgetTopGlow.opacity(viewModel.isOffline ? 0.04 : 0.16))
                        .frame(width: 150, height: 150)
                        .blur(radius: 36)
                        .offset(x: -18, y: -40)
                }
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(ColorPalette.widgetBottomGlow.opacity(0.18))
                        .frame(width: 110, height: 110)
                        .blur(radius: 30)
                        .offset(x: 20, y: 24)
                }
                .overlay(
                    widgetShape
                        .stroke(ColorPalette.panelEdge, lineWidth: 1)
                )
                .overlay(
                    widgetShape
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.6)
                        .blur(radius: 0.2)
                )
                .shadow(color: ColorPalette.widgetShadow, radius: 24, x: 0, y: 10)

            Group {
                ZStack {
                    if viewModel.isCompactMode {
                        CompactWidgetView(viewModel: viewModel)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                    removal: .opacity
                                )
                            )
                    } else {
                        FullWidgetView(viewModel: viewModel)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 1.01)),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: viewModel.isCompactMode)
            }
            .padding(EdgeInsets(metrics.contentPadding))
        }
        .clipShape(widgetShape)
        .compositingGroup()
        .frame(width: metrics.size.width, height: metrics.size.height)
        .background(
            WindowAccessor { window in
                windowPlacementService.bind(window: window, to: viewModel)
            }
        )
        .animation(.easeInOut(duration: 0.5), value: viewModel.isOffline)
        .background(Color.clear)
        .contextMenu {
            Button(viewModel.toggleVisibilityMenuText) {
                viewModel.setWindowVisible(!viewModel.isWindowVisible)
            }

            Button(viewModel.toggleModeMenuText) {
                Task {
                    await viewModel.toggleCompactMode()
                }
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
}
