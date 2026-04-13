import Foundation

public enum RateMath {
    public static func createSnapshot(
        pair: String,
        range: TimeRangePreset,
        points: [RatePoint],
        currentRateOverride: Decimal? = nil,
        asOfUTC: Date? = nil,
        isStale: Bool = false
    ) -> RateSeriesSnapshot {
        let orderedPoints = points.sorted { $0.timestampUTC < $1.timestampUTC }
        let currentRate = currentRateOverride ?? orderedPoints.last?.rate ?? 0
        let anchorRate = orderedPoints.first?.rate ?? currentRate
        let changeAbsolute = currentRate - anchorRate
        let changePercent = anchorRate == 0 ? 0 : (changeAbsolute / anchorRate) * 100

        return RateSeriesSnapshot(
            pair: pair,
            range: range,
            points: orderedPoints,
            currentRate: currentRate,
            changeAbsolute: changeAbsolute,
            changePercent: changePercent,
            asOfUTC: asOfUTC ?? orderedPoints.last?.timestampUTC ?? Date(),
            isStale: isStale
        )
    }

    public static func appendOrReplaceLatest(_ points: [RatePoint], latestPoint: RatePoint) -> [RatePoint] {
        var merged = points.sorted { $0.timestampUTC < $1.timestampUTC }

        guard let lastPoint = merged.last else {
            return [latestPoint]
        }

        if latestPoint.timestampUTC <= lastPoint.timestampUTC {
            merged[merged.count - 1] = latestPoint
        } else {
            merged.append(latestPoint)
        }

        return merged
    }

    public static func downsample(_ points: [RatePoint], maxPoints: Int) -> [RatePoint] {
        guard points.count > maxPoints, maxPoints > 1 else {
            return points
        }

        let step = Double(points.count - 1) / Double(maxPoints - 1)
        return (0..<maxPoints).map { index in
            let pointIndex = min(Int((Double(index) * step).rounded()), points.count - 1)
            return points[pointIndex]
        }
    }

    public static func scalePoints(_ points: [RatePoint], multiplier: Decimal) -> [RatePoint] {
        points.map { RatePoint(timestampUTC: $0.timestampUTC, rate: $0.rate * multiplier) }
    }

    public static func formatDisplayAmount(_ value: Decimal) -> String {
        formatDecimal(value, rules: [(1000, "#,##0.##"), (1, "#,##0.####"), (0, "0.######")])
    }

    public static func formatSignedAmount(_ value: Decimal) -> String {
        "\(value > 0 ? "+" : "")\(formatDisplayAmount(value))"
    }

    public static func formatBaseAmount(_ value: Decimal) -> String {
        formatDecimal(value, rules: [(1000, "#,##0.##"), (1, "#,##0.####"), (0, "0.####")])
    }

    public static func determineAxisDecimalPlaces(
        values: [Decimal],
        minimumDecimals: Int = 2,
        maximumDecimals: Int = 8
    ) -> Int {
        guard values.count > 1 else {
            return minimumDecimals
        }

        for decimals in minimumDecimals...maximumDecimals {
            let labels = values.map { formatAxisValue($0, decimals: decimals) }
            if Set(labels).count == labels.count {
                return decimals
            }
        }

        return maximumDecimals
    }

    public static func formatAxisValue(_ value: Decimal, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    public static func formatUpdatedAt(_ date: Date?) -> String {
        guard let date else {
            return "Updated at: --"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return "Updated at: \(formatter.string(from: date))"
    }

    public static func extractCompactStatusText(_ text: String) -> String {
        let prefix = "Updated at:"
        guard text.hasPrefix(prefix) else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let compactText = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return compactText.isEmpty ? "--" : compactText
    }

    public static func chartTimestampLabel(for timestamp: Date, minDate: Date, maxDate: Date) -> String {
        let span = maxDate.timeIntervalSince(minDate)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        switch span {
        case ...172_800:
            formatter.dateFormat = "HH:mm"
        case ...3_888_000:
            formatter.dateFormat = "MM-dd"
        case ...34_560_000:
            formatter.dateFormat = "yy-MM"
        default:
            formatter.dateFormat = "yyyy-MM"
        }

        return formatter.string(from: timestamp)
    }

    public static func displayPairLabel(baseAmount: Decimal, baseCurrency: String, quoteCurrency: String) -> String {
        "\(formatBaseAmount(baseAmount)) \(baseCurrency)/\(quoteCurrency)"
    }

    private static func formatDecimal(_ value: Decimal, rules: [(Decimal, String)]) -> String {
        let absoluteValue = NSDecimalNumber(decimal: value).doubleValue.magnitude
        let format = rules.first { absoluteValue >= NSDecimalNumber(decimal: $0.0).doubleValue }?.1 ?? "0.######"
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.positiveFormat = format
        formatter.negativeFormat = "-\(format)"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
