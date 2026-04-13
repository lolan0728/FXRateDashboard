import Foundation

public enum TokenUpdate: Equatable, Sendable {
    case unchanged
    case set(String)
    case clear
}

public enum SettingsValidationError: LocalizedError {
    case invalidCurrency
    case invalidBaseAmount
    case invalidRefreshInterval

    public var errorDescription: String? {
        switch self {
        case .invalidCurrency:
            "Base and quote currency must be valid ISO 4217 codes, for example USD and CNY."
        case .invalidBaseAmount:
            "Base amount must be a positive number."
        case .invalidRefreshInterval:
            "Refresh interval must be between 15 and 3600 seconds."
        }
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var baseCurrency = "USD"
    @Published public var quoteCurrency = "CNY"
    @Published public var baseAmountText = "1"
    @Published public var refreshSecondsText = "60"
    @Published public var lockPosition = false
    @Published public var launchAtStartup = false
    @Published public var apiTokenText = ""
    @Published public var tokenHelpText = "Paste token."

    private var loadedSettings = AppSettings()
    private var existingTokenMask: String?
    private var hasStoredToken = false

    public init() {}

    public func load(from settings: AppSettings, hasToken: Bool, maskedToken: String?) {
        loadedSettings = settings
        hasStoredToken = hasToken
        existingTokenMask = maskedToken

        baseCurrency = settings.baseCurrency
        quoteCurrency = settings.quoteCurrency
        baseAmountText = RateMath.formatBaseAmount(settings.baseAmount)
        refreshSecondsText = String(settings.refreshSeconds)
        lockPosition = settings.lockPosition
        launchAtStartup = settings.launchAtStartup
        apiTokenText = maskedToken ?? ""
        tokenHelpText = maskedToken == nil ? "Paste token." : "Replace or clear it."
    }

    public func buildSettings() throws -> AppSettings {
        let normalizedBase = normalizeCurrency(baseCurrency)
        let normalizedQuote = normalizeCurrency(quoteCurrency)

        guard let normalizedBase, let normalizedQuote else {
            throw SettingsValidationError.invalidCurrency
        }

        guard let baseAmount = parsePositiveDecimal(baseAmountText) else {
            throw SettingsValidationError.invalidBaseAmount
        }

        guard let refreshSeconds = Int(refreshSecondsText), (15...3600).contains(refreshSeconds) else {
            throw SettingsValidationError.invalidRefreshInterval
        }

        var settings = loadedSettings
        settings.baseCurrency = normalizedBase
        settings.quoteCurrency = normalizedQuote
        settings.baseAmount = baseAmount
        settings.refreshSeconds = refreshSeconds
        settings.lockPosition = lockPosition
        settings.launchAtStartup = launchAtStartup
        return settings.normalized()
    }

    public func resolveTokenUpdate() -> TokenUpdate {
        let normalizedInput = Self.normalizeTokenInput(apiTokenText)
        guard let normalizedInput, !normalizedInput.isEmpty else {
            return hasStoredToken ? .clear : .unchanged
        }

        if normalizedInput == existingTokenMask {
            return .unchanged
        }

        return .set(normalizedInput)
    }

    public static func normalizeTokenInput(_ value: String?) -> String? {
        guard var token = value?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }

        if token.lowercased().hasPrefix("authorization:") {
            token = String(token.dropFirst("Authorization:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if token.lowercased().hasPrefix("bearer ") {
            token = String(token.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        token = token.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return token.isEmpty ? nil : token
    }

    public static func maskToken(_ token: String) -> String {
        let visibleLead = min(4, max(2, token.count / 4))
        let visibleTail = min(4, max(2, token.count / 4))
        let hiddenLength = max(token.count - visibleLead - visibleTail, 0)
        guard hiddenLength > 0 else {
            return token
        }

        let head = token.prefix(visibleLead)
        let tail = token.suffix(visibleTail)
        return "\(head)\(String(repeating: "*", count: hiddenLength))\(tail)"
    }

    private func normalizeCurrency(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().filter(\.isLetter)
        guard cleaned.count == 3, CurrencyCodeCatalog.isKnownCode(cleaned) else {
            return nil
        }

        return cleaned
    }

    private func parsePositiveDecimal(_ value: String) -> Decimal? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let locales = [
            Locale.current,
            Locale(identifier: "en_US_POSIX")
        ]

        for locale in locales {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.generatesDecimalNumbers = true
            formatter.isLenient = true

            if let number = formatter.number(from: trimmed) {
                let decimal = number.decimalValue
                if decimal > 0 {
                    return decimal
                }
            }
        }

        return nil
    }
}
