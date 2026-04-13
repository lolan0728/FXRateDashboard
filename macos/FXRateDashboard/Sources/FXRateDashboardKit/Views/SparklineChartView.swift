import SwiftUI

public struct SparklineChartView: View {
    private let points: [RatePoint]
    private let strokeColor: Color

    private let plotLeftMargin: CGFloat = 46
    private let plotTopMargin: CGFloat = 14
    private let plotRightMargin: CGFloat = 4
    private let plotBottomMargin: CGFloat = 10
    private let plotInnerPadding: CGFloat = 6
    private let axisLabelSafeInset: CGFloat = 6
    private let edgeTickLift: CGFloat = 8

    public init(points: [RatePoint], strokeColor: Color) {
        self.points = points
        self.strokeColor = strokeColor
    }

    public var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let plotRect = CGRect(
                    x: plotLeftMargin,
                    y: plotTopMargin,
                    width: max(size.width - plotLeftMargin - plotRightMargin, 1),
                    height: max(size.height - plotTopMargin - plotBottomMargin, 1)
                )

                guard plotRect.width > 0, plotRect.height > 0 else {
                    return
                }

                guard !points.isEmpty else {
                    drawEmptyState(in: context, plotRect: plotRect, canvasSize: size)
                    return
                }

                let values = points.map(\.rate)
                let minValue = values.min() ?? 0
                let maxValue = values.max() ?? 0
                let rangePadding = max((maxValue - minValue) * 0.08, Decimal(string: "0.0001")!)
                let paddedMin = minValue == maxValue ? minValue - 0.5 : minValue - rangePadding
                let paddedMax = minValue == maxValue ? maxValue + 0.5 : maxValue + rangePadding

                drawAxes(
                    in: context,
                    plotRect: plotRect,
                    canvasSize: size,
                    minValue: paddedMin,
                    maxValue: paddedMax
                )

                let chartPoints = buildChartPoints(plotRect: plotRect, minValue: paddedMin, maxValue: paddedMax)
                guard chartPoints.count > 1 else {
                    return
                }

                var linePath = Path()
                linePath.addLines(chartPoints)

                var fillPath = linePath
                fillPath.addLine(to: CGPoint(x: chartPoints.last!.x, y: plotRect.maxY))
                fillPath.addLine(to: CGPoint(x: chartPoints.first!.x, y: plotRect.maxY))
                fillPath.closeSubpath()

                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [strokeColor.opacity(0.22), strokeColor.opacity(0.02)]),
                        startPoint: CGPoint(x: 0, y: plotRect.minY),
                        endPoint: CGPoint(x: 0, y: plotRect.maxY)
                    )
                )

                context.stroke(
                    linePath,
                    with: .color(strokeColor),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )

                if let lastPoint = chartPoints.last {
                    context.fill(Path(ellipseIn: CGRect(x: lastPoint.x - 8, y: lastPoint.y - 8, width: 16, height: 16)), with: .color(strokeColor.opacity(0.18)))
                    context.fill(Path(ellipseIn: CGRect(x: lastPoint.x - 4.5, y: lastPoint.y - 4.5, width: 9, height: 9)), with: .color(strokeColor))
                }
            }
        }
        .frame(minHeight: 220, idealHeight: 228, maxHeight: 228)
    }

    private func drawEmptyState(in context: GraphicsContext, plotRect: CGRect, canvasSize: CGSize) {
        drawEmptyGrid(in: context, plotRect: plotRect)

        let text = Text("Waiting for rate data")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(ColorPalette.mutedTextOffline)

        context.draw(text, at: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2))
    }

    private func drawAxes(
        in context: GraphicsContext,
        plotRect: CGRect,
        canvasSize: CGSize,
        minValue: Decimal,
        maxValue: Decimal
    ) {
        let valueTicks = tickValues(minValue: minValue, maxValue: maxValue, count: 4)
        let decimals = RateMath.determineAxisDecimalPlaces(values: valueTicks)

        for index in valueTicks.indices {
            let tick = valueTicks[index]
            let normalized = maxValue == minValue ? 0.5 : CGFloat(NSDecimalNumber(decimal: (tick - minValue) / (maxValue - minValue)).doubleValue)
            var y = plotRect.maxY - plotInnerPadding - ((plotRect.height - (plotInnerPadding * 2)) * normalized)

            if index == 0 {
                y += edgeTickLift
            } else if index == valueTicks.count - 1 {
                y -= edgeTickLift
            }

            var path = Path()
            path.move(to: CGPoint(x: plotRect.minX, y: y))
            path.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(path, with: .color(ColorPalette.brandForestGreen.opacity(0.12)), lineWidth: 1)

            let label = Text(RateMath.formatAxisValue(tick, decimals: decimals))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(ColorPalette.mutedTextOnline)

            let labelY = min(max(y, axisLabelSafeInset), canvasSize.height - axisLabelSafeInset)
            context.draw(label, at: CGPoint(x: plotRect.minX - 2, y: labelY), anchor: .trailing)
        }

        let distinctIndices = orderedTimeTickIndices()

        for index in distinctIndices where points.indices.contains(index) {
            let ratio = points.count == 1 ? 0 : CGFloat(index) / CGFloat(points.count - 1)
            let x = plotRect.minX + plotInnerPadding + ((plotRect.width - (plotInnerPadding * 2)) * ratio)
            var path = Path()
            path.move(to: CGPoint(x: x, y: plotRect.minY))
            path.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(path, with: .color(ColorPalette.brandForestGreen.opacity(0.09)), lineWidth: 1)
        }
    }

    private func drawEmptyGrid(in context: GraphicsContext, plotRect: CGRect) {
        for index in 0..<4 {
            let ratio = CGFloat(index) / 3
            let y = plotRect.minY + plotInnerPadding + ((plotRect.height - (plotInnerPadding * 2)) * ratio)
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: plotRect.minX, y: y))
            horizontal.addLine(to: CGPoint(x: plotRect.maxX, y: y))
            context.stroke(horizontal, with: .color(ColorPalette.brandForestGreen.opacity(0.12)), lineWidth: 1)

            let x = plotRect.minX + plotInnerPadding + ((plotRect.width - (plotInnerPadding * 2)) * ratio)
            var vertical = Path()
            vertical.move(to: CGPoint(x: x, y: plotRect.minY))
            vertical.addLine(to: CGPoint(x: x, y: plotRect.maxY))
            context.stroke(vertical, with: .color(ColorPalette.brandForestGreen.opacity(0.09)), lineWidth: 1)
        }
    }

    private func buildChartPoints(plotRect: CGRect, minValue: Decimal, maxValue: Decimal) -> [CGPoint] {
        guard !points.isEmpty else {
            return []
        }

        return points.enumerated().map { index, point in
            let xRatio = points.count == 1 ? 0.5 : CGFloat(index) / CGFloat(points.count - 1)
            let normalizedY = maxValue == minValue
                ? 0.5
                : CGFloat(NSDecimalNumber(decimal: (point.rate - minValue) / (maxValue - minValue)).doubleValue)

            return CGPoint(
                x: plotRect.minX + plotInnerPadding + ((plotRect.width - (plotInnerPadding * 2)) * xRatio),
                y: plotRect.maxY - plotInnerPadding - ((plotRect.height - (plotInnerPadding * 2)) * normalizedY)
            )
        }
    }

    private func tickValues(minValue: Decimal, maxValue: Decimal, count: Int) -> [Decimal] {
        guard count > 1 else {
            return [minValue]
        }

        let step = (maxValue - minValue) / Decimal(count - 1)
        return (0..<count).map { minValue + (step * Decimal($0)) }
    }

    private func orderedTimeTickIndices() -> [Int] {
        guard !points.isEmpty else {
            return []
        }

        if points.count <= 4 {
            return Array(points.indices)
        }

        let last = points.count - 1
        let values = [
            0,
            Int(round(Double(last) * 0.33)),
            Int(round(Double(last) * 0.66)),
            last
        ]

        return Array(NSOrderedSet(array: values)) as? [Int] ?? values
    }
}
