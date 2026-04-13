import Foundation

public protocol RateQueryMapperProtocol: Sendable {
    func mapHistoryQuery(_ range: TimeRangePreset, nowUTC: Date) -> RateHistoryQuery
}

public struct RateQueryMapper: RateQueryMapperProtocol {
    public init() {}

    public func mapHistoryQuery(_ range: TimeRangePreset, nowUTC: Date = Date()) -> RateHistoryQuery {
        let anchor = nowUTC

        return switch range {
        case .day:
            RateHistoryQuery(range: range, fromUTC: anchor.addingTimeInterval(-86_400), toUTC: anchor, group: "minute")
        case .week:
            RateHistoryQuery(range: range, fromUTC: anchor.addingTimeInterval(-604_800), toUTC: anchor, group: "hour")
        case .month:
            RateHistoryQuery(range: range, fromUTC: anchor.addingTimeInterval(-2_592_000), toUTC: anchor, group: "day")
        case .year:
            RateHistoryQuery(range: range, fromUTC: anchor.addingTimeInterval(-31_536_000), toUTC: anchor, group: "day")
        }
    }
}
