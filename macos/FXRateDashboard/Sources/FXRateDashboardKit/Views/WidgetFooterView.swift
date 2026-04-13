import SwiftUI

public struct WidgetFooterView: View {
    @ObservedObject private var viewModel: MainWidgetViewModel

    public init(viewModel: MainWidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(TimeRangePreset.allCases, id: \.self) { range in
                Button(range.title) {
                    Task {
                        await viewModel.selectRange(range)
                    }
                }
                .buttonStyle(RangeButtonStyle(isActive: viewModel.activeRange == range, isOffline: viewModel.isOffline))
            }

            Spacer(minLength: 12)

            Text("Wise")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(viewModel.mutedTextColor)
        }
    }
}

private struct RangeButtonStyle: ButtonStyle {
    let isActive: Bool
    let isOffline: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.82 : 1))
                    .overlay(
                        Circle()
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
    }

    private var backgroundColor: Color {
        guard isActive else {
            return Color.white.opacity(0.72)
        }

        return isOffline ? ColorPalette.accentOffline : ColorPalette.brandBrightGreen
    }

    private var foregroundColor: Color {
        guard isActive else {
            return ColorPalette.mutedTextOnline
        }

        return isOffline ? ColorPalette.primaryTextOffline : ColorPalette.brandForestGreen
    }

    private var borderColor: Color {
        isActive ? backgroundColor : ColorPalette.panelEdge
    }
}
