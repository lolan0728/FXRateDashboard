import Foundation

public struct RateHistoryQuery: Equatable, Sendable {
    public var range: TimeRangePreset
    public var fromUTC: Date
    public var toUTC: Date
    public var group: String

    public init(range: TimeRangePreset, fromUTC: Date, toUTC: Date, group: String) {
        self.range = range
        self.fromUTC = fromUTC
        self.toUTC = toUTC
        self.group = group
    }
}
