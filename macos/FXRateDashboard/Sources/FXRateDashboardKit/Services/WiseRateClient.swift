import Foundation

public protocol WiseRateClientProtocol: Sendable {
    func getCurrentRate(source: String, target: String, token: String) async throws -> RatePoint
    func getHistoricalRates(
        source: String,
        target: String,
        token: String,
        fromUTC: Date,
        toUTC: Date,
        group: String
    ) async throws -> [RatePoint]
}

public enum WiseRateClientError: LocalizedError {
    case invalidToken
    case rateLimited
    case emptyResponse
    case invalidTimestamp
    case requestFailed

    public var errorDescription: String? {
        switch self {
        case .invalidToken:
            "The Wise token is invalid or does not have enough permission. Please update it in Settings with a new read-only token."
        case .rateLimited:
            "Wise rate limits were hit. Please try again in a moment."
        case .emptyResponse:
            "Wise did not return a current rate."
        case .invalidTimestamp:
            "Wise returned an unrecognized timestamp format."
        case .requestFailed:
            "Wise request failed. Please check your connection and try again."
        }
    }
}

public final class WiseRateClient: WiseRateClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let baseURL: URL

    public init(session: URLSession = .shared, baseURL: URL = URL(string: "https://api.wise.com/")!) {
        self.session = session
        self.baseURL = baseURL
    }

    public func getCurrentRate(source: String, target: String, token: String) async throws -> RatePoint {
        let items = try await sendRequest(
            path: "v1/rates",
            queryItems: [
                URLQueryItem(name: "source", value: source),
                URLQueryItem(name: "target", value: target)
            ],
            token: token
        )

        guard let item = items.first else {
            throw WiseRateClientError.emptyResponse
        }

        return RatePoint(timestampUTC: try Self.parseWiseTimestamp(item.time), rate: item.rate)
    }

    public func getHistoricalRates(
        source: String,
        target: String,
        token: String,
        fromUTC: Date,
        toUTC: Date,
        group: String
    ) async throws -> [RatePoint] {
        let items = try await sendRequest(
            path: "v1/rates",
            queryItems: [
                URLQueryItem(name: "source", value: source),
                URLQueryItem(name: "target", value: target),
                URLQueryItem(name: "from", value: Self.formatTimestamp(fromUTC)),
                URLQueryItem(name: "to", value: Self.formatTimestamp(toUTC)),
                URLQueryItem(name: "group", value: group)
            ],
            token: token
        )

        return try items
            .map { RatePoint(timestampUTC: try Self.parseWiseTimestamp($0.time), rate: $0.rate) }
            .sorted { $0.timestampUTC < $1.timestampUTC }
    }

    private func sendRequest(
        path: String,
        queryItems: [URLQueryItem],
        token: String
    ) async throws -> [WiseRateResponse] {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WiseRateClientError.requestFailed
        }

        switch httpResponse.statusCode {
        case 200 ..< 300:
            return try JSONDecoder().decode([WiseRateResponse].self, from: data)
        case 401, 403:
            throw WiseRateClientError.invalidToken
        case 429:
            throw WiseRateClientError.rateLimited
        default:
            throw WiseRateClientError.requestFailed
        }
    }

    static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }

    static func parseWiseTimestamp(_ value: String) throws -> Date {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WiseRateClientError.invalidTimestamp
        }

        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.range(of: #"[+-]\d{4}$"#, options: .regularExpression) != nil {
            let start = normalized.index(normalized.endIndex, offsetBy: -5)
            let middle = normalized.index(normalized.endIndex, offsetBy: -2)
            normalized.insert(":", at: middle)
            if normalized[start] != "+" && normalized[start] != "-" {
                normalized = String(normalized)
            }
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: normalized) ?? {
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: normalized)
        }() {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(secondsFromGMT: 0)
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = fallback.date(from: normalized) {
            return date
        }

        throw WiseRateClientError.invalidTimestamp
    }
}

private struct WiseRateResponse: Codable {
    let rate: Decimal
    let source: String
    let target: String
    let time: String
}
