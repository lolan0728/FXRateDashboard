import SwiftUI

public struct WidgetValueSectionView: View {
    @ObservedObject private var viewModel: MainWidgetViewModel
    private let compactTrailingColumnWidth: CGFloat = 76

    public init(viewModel: MainWidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: viewModel.isCompactMode ? 8 : 2) {
            HStack(alignment: .top, spacing: 6) {
                Text(viewModel.currentRateDisplay)
                    .font(.system(size: viewModel.metrics.currentValueFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(viewModel.primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .tracking(-0.6)

                Text(viewModel.quoteCurrencyCode)
                    .font(.system(size: viewModel.metrics.quoteCurrencyFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(viewModel.mutedTextColor)
                    .padding(.top, viewModel.metrics.quoteCurrencyTopPadding)
            }

            HStack {
                HStack(spacing: 8) {
                    Text(viewModel.changeDisplay)
                    Text(viewModel.changePercentDisplay)
                }
                .font(.system(size: viewModel.metrics.changeFontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(viewModel.trendColor)

                Spacer(minLength: 8)

                if viewModel.isCompactMode {
                    Text(viewModel.footerSourceText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.mutedTextColor)
                        .frame(width: compactTrailingColumnWidth, alignment: .center)
                        .offset(x: 8)
                }
            }
        }
    }
}
