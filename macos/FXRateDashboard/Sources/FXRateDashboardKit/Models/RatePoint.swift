import Foundation

public struct RatePoint: Codable, Equatable, Sendable {
    public var timestampUTC: Date
    public var rate: Decimal

    public init(timestampUTC: Date, rate: Decimal) {
        self.timestampUTC = timestampUTC
        self.rate = rate
    }
}
