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
