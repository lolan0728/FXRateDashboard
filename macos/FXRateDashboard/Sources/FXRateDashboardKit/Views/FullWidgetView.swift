import SwiftUI

public struct FullWidgetView: View {
    @ObservedObject private var viewModel: MainWidgetViewModel

    public init(viewModel: MainWidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetTopBarView(viewModel: viewModel)
            WidgetValueSectionView(viewModel: viewModel)
                .padding(.top, 8)

            SparklineChartView(points: viewModel.chartPoints, strokeColor: viewModel.trendColor)
                .padding(.top, viewModel.metrics.chartTopMargin)
                .padding(.bottom, viewModel.metrics.chartBottomMargin)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(viewModel.chartCardBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(ColorPalette.panelEdge, lineWidth: 1)
                        )
                )
                .padding(.top, 6)
                .padding(.bottom, 6)

            WidgetFooterView(viewModel: viewModel)
                .padding(.bottom, 0)
        }
    }
}
