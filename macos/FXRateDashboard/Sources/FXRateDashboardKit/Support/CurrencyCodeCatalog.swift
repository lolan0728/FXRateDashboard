import Foundation

public enum CurrencyCodeCatalog {
    private static let knownCodes = Set(Locale.commonISOCurrencyCodes.map { $0.uppercased() })

    public static func isKnownCode(_ code: String) -> Bool {
        knownCodes.contains(code.uppercased())
    }
}
