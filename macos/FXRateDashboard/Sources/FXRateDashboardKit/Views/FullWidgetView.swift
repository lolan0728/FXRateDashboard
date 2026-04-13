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
                .padding(.top, 10)

            SparklineChartView(points: viewModel.chartPoints, strokeColor: viewModel.trendColor)
                .padding(.top, viewModel.metrics.chartTopMargin)
                .padding(.bottom, viewModel.metrics.chartBottomMargin)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(viewModel.chartCardBackgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(ColorPalette.panelEdge, lineWidth: 1)
                        )
                )
                .padding(.top, 10)
                .padding(.bottom, 14)

            WidgetFooterView(viewModel: viewModel)
                .padding(.bottom, 2)
        }
    }
}
