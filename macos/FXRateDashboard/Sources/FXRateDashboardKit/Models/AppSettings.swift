import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var baseCurrency: String
    public var quoteCurrency: String
    public var baseAmount: Decimal
    public var activeRange: TimeRangePreset
    public var refreshSeconds: Int
    public var isCompactMode: Bool
    public var windowOriginX: Double?
    public var windowOriginY: Double?
    public var fullWindowOriginX: Double?
    public var fullWindowOriginY: Double?
    public var compactWindowOriginX: Double?
    public var compactWindowOriginY: Double?
    public var lockPosition: Bool
    public var clickThroughEnabled: Bool
    public var launchAtStartup: Bool
    public var hasStoredToken: Bool

    public init(
        baseCurrency: String = "USD",
        quoteCurrency: String = "CNY",
        baseAmount: Decimal = 1,
        activeRange: TimeRangePreset = .day,
        refreshSeconds: Int = 60,
        isCompactMode: Bool = false,
        windowOriginX: Double? = nil,
        windowOriginY: Double? = nil,
        fullWindowOriginX: Double? = nil,
        fullWindowOriginY: Double? = nil,
        compactWindowOriginX: Double? = nil,
        compactWindowOriginY: Double? = nil,
        lockPosition: Bool = false,
        clickThroughEnabled: Bool = false,
        launchAtStartup: Bool = false,
        hasStoredToken: Bool = false
    ) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        self.baseAmount = baseAmount
        self.activeRange = activeRange
        self.refreshSeconds = refreshSeconds
        self.isCompactMode = isCompactMode
        self.windowOriginX = windowOriginX
        self.windowOriginY = windowOriginY
        self.fullWindowOriginX = fullWindowOriginX
        self.fullWindowOriginY = fullWindowOriginY
        self.compactWindowOriginX = compactWindowOriginX
        self.compactWindowOriginY = compactWindowOriginY
        self.lockPosition = lockPosition
        self.clickThroughEnabled = clickThroughEnabled
        self.launchAtStartup = launchAtStartup
        self.hasStoredToken = hasStoredToken
    }

    public var pair: String {
        "\(baseCurrency)/\(quoteCurrency)"
    }

    public func normalized() -> AppSettings {
        var copy = self
        copy.baseCurrency = Self.normalizeCurrency(baseCurrency, fallback: "USD")
        copy.quoteCurrency = Self.normalizeCurrency(quoteCurrency, fallback: "CNY")
        copy.baseAmount = baseAmount <= 0 ? 1 : baseAmount.rounded(scale: 4)
        copy.refreshSeconds = min(max(refreshSeconds, 15), 3600)
        copy.migrateLegacyWindowOriginIfNeeded()
        return copy
    }

    private mutating func migrateLegacyWindowOriginIfNeeded() {
        guard let windowOriginX, let windowOriginY else {
            return
        }

        if isCompactMode {
            compactWindowOriginX = compactWindowOriginX ?? windowOriginX
            compactWindowOriginY = compactWindowOriginY ?? windowOriginY
        } else {
            fullWindowOriginX = fullWindowOriginX ?? windowOriginX
            fullWindowOriginY = fullWindowOriginY ?? windowOriginY
        }
    }

    private static func normalizeCurrency(_ value: String, fallback: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .filter(\.isLetter)

        return cleaned.count == 3 ? cleaned : fallback
    }
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case baseCurrency
        case quoteCurrency
        case baseAmount
        case activeRange
        case refreshSeconds
        case isCompactMode
        case windowOriginX
        case windowOriginY
        case fullWindowOriginX
        case fullWindowOriginY
        case compactWindowOriginX
        case compactWindowOriginY
        case lockPosition
        case clickThroughEnabled
        case launchAtStartup
        case hasStoredToken
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        baseCurrency = try container.decodeIfPresent(String.self, forKey: .baseCurrency) ?? "USD"
        quoteCurrency = try container.decodeIfPresent(String.self, forKey: .quoteCurrency) ?? "CNY"
        baseAmount = try container.decodeIfPresent(Decimal.self, forKey: .baseAmount) ?? 1
        activeRange = try container.decodeIfPresent(TimeRangePreset.self, forKey: .activeRange) ?? .day
        refreshSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshSeconds) ?? 60
        isCompactMode = try container.decodeIfPresent(Bool.self, forKey: .isCompactMode) ?? false
        windowOriginX = try container.decodeIfPresent(Double.self, forKey: .windowOriginX)
        windowOriginY = try container.decodeIfPresent(Double.self, forKey: .windowOriginY)
        fullWindowOriginX = try container.decodeIfPresent(Double.self, forKey: .fullWindowOriginX)
        fullWindowOriginY = try container.decodeIfPresent(Double.self, forKey: .fullWindowOriginY)
        compactWindowOriginX = try container.decodeIfPresent(Double.self, forKey: .compactWindowOriginX)
        compactWindowOriginY = try container.decodeIfPresent(Double.self, forKey: .compactWindowOriginY)
        lockPosition = try container.decodeIfPresent(Bool.self, forKey: .lockPosition) ?? false
        clickThroughEnabled = try container.decodeIfPresent(Bool.self, forKey: .clickThroughEnabled) ?? false
        launchAtStartup = try container.decodeIfPresent(Bool.self, forKey: .launchAtStartup) ?? false
        hasStoredToken = try container.decodeIfPresent(Bool.self, forKey: .hasStoredToken) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(baseCurrency, forKey: .baseCurrency)
        try container.encode(quoteCurrency, forKey: .quoteCurrency)
        try container.encode(baseAmount, forKey: .baseAmount)
        try container.encode(activeRange, forKey: .activeRange)
        try container.encode(refreshSeconds, forKey: .refreshSeconds)
        try container.encode(isCompactMode, forKey: .isCompactMode)
        try container.encodeIfPresent(windowOriginX, forKey: .windowOriginX)
        try container.encodeIfPresent(windowOriginY, forKey: .windowOriginY)
        try container.encodeIfPresent(fullWindowOriginX, forKey: .fullWindowOriginX)
        try container.encodeIfPresent(fullWindowOriginY, forKey: .fullWindowOriginY)
        try container.encodeIfPresent(compactWindowOriginX, forKey: .compactWindowOriginX)
        try container.encodeIfPresent(compactWindowOriginY, forKey: .compactWindowOriginY)
        try container.encode(lockPosition, forKey: .lockPosition)
        try container.encode(clickThroughEnabled, forKey: .clickThroughEnabled)
        try container.encode(launchAtStartup, forKey: .launchAtStartup)
        try container.encode(hasStoredToken, forKey: .hasStoredToken)
    }
}
