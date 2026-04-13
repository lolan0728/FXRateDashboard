import Foundation

public enum TimeRangePreset: String, Codable, CaseIterable, Sendable {
    case day
    case week
    case month
    case year

    public var title: String {
        switch self {
        case .day:
            "1D"
        case .week:
            "1W"
        case .month:
            "1M"
        case .year:
            "1Y"
        }
    }
}
