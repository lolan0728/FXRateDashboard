import CoreGraphics

public struct WidgetMetrics: Sendable {
    public let size: CGSize
    public let outerMargin: CGFloat
    public let contentPadding: EdgeInsetsValue
    public let cornerRadius: CGFloat
    public let pairLabelFontSize: CGFloat
    public let pairLabelPadding: EdgeInsetsValue
    public let statusChipFontSize: CGFloat
    public let statusChipPadding: EdgeInsetsValue
    public let statusChipMinWidth: CGFloat
    public let currentValueFontSize: CGFloat
    public let quoteCurrencyFontSize: CGFloat
    public let changeFontSize: CGFloat
    public let quoteCurrencyTopPadding: CGFloat
    public let chartTopMargin: CGFloat
    public let chartBottomMargin: CGFloat

    public static let full = WidgetMetrics(
        size: CGSize(width: 404, height: 452),
        outerMargin: 12,
        contentPadding: .init(top: 20, leading: 20, bottom: 18, trailing: 20),
        cornerRadius: 32,
        pairLabelFontSize: 12,
        pairLabelPadding: .init(top: 5, leading: 10, bottom: 5, trailing: 10),
        statusChipFontSize: 11,
        statusChipPadding: .init(top: 4, leading: 8, bottom: 4, trailing: 8),
        statusChipMinWidth: 0,
        currentValueFontSize: 42,
        quoteCurrencyFontSize: 13,
        changeFontSize: 15,
        quoteCurrencyTopPadding: 16,
        chartTopMargin: 10,
        chartBottomMargin: 8
    )

    public static let compact = WidgetMetrics(
        size: CGSize(width: 236, height: 104),
        outerMargin: 7,
        contentPadding: .init(top: 8, leading: 9, bottom: 2, trailing: 7),
        cornerRadius: 24,
        pairLabelFontSize: 10,
        pairLabelPadding: .init(top: 4, leading: 7, bottom: 4, trailing: 7),
        statusChipFontSize: 9,
        statusChipPadding: .init(top: 3, leading: 5, bottom: 3, trailing: 5),
        statusChipMinWidth: 34,
        currentValueFontSize: 27,
        quoteCurrencyFontSize: 10,
        changeFontSize: 11,
        quoteCurrencyTopPadding: 8,
        chartTopMargin: 0,
        chartBottomMargin: 0
    )
}

public struct EdgeInsetsValue: Sendable {
    public let top: CGFloat
    public let leading: CGFloat
    public let bottom: CGFloat
    public let trailing: CGFloat

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}
