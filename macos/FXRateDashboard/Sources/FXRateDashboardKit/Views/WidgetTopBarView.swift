import SwiftUI

public struct WidgetTopBarView: View {
    @ObservedObject private var viewModel: MainWidgetViewModel
    private let compactTrailingColumnWidth: CGFloat = 76

    public init(viewModel: MainWidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 8) {
            Text(viewModel.pairLabel)
                .font(.system(size: viewModel.metrics.pairLabelFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(viewModel.primaryTextColor)
                .padding(EdgeInsets(viewModel.metrics.pairLabelPadding))
                .background(viewModel.accentColor, in: Capsule())

            Spacer(minLength: 8)

            Text(viewModel.statusChipText)
                .font(.system(size: viewModel.metrics.statusChipFontSize, weight: .medium, design: .rounded))
                .foregroundStyle(viewModel.mutedTextColor)
                .lineLimit(1)
                .frame(minWidth: viewModel.metrics.statusChipMinWidth)
                .padding(EdgeInsets(viewModel.metrics.statusChipPadding))
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.statusChipBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(ColorPalette.panelEdge, lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 1)
                .frame(
                    width: viewModel.isCompactMode ? compactTrailingColumnWidth : nil,
                    alignment: .center
                )
                .offset(x: viewModel.isCompactMode ? 8 : 0)
        }
    }
}
