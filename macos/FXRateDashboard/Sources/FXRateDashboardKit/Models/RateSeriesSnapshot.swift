import Foundation

public struct RateSeriesSnapshot: Codable, Equatable, Sendable {
    public var pair: String
    public var range: TimeRangePreset
    public var points: [RatePoint]
    public var currentRate: Decimal
    public var changeAbsolute: Decimal
    public var changePercent: Decimal
    public var asOfUTC: Date
    public var isStale: Bool

    public init(
        pair: String,
        range: TimeRangePreset,
        points: [RatePoint],
        currentRate: Decimal,
        changeAbsolute: Decimal,
        changePercent: Decimal,
        asOfUTC: Date,
        isStale: Bool
    ) {
        self.pair = pair
        self.range = range
        self.points = points
        self.currentRate = currentRate
        self.changeAbsolute = changeAbsolute
        self.changePercent = changePercent
        self.asOfUTC = asOfUTC
        self.isStale = isStale
    }
}
