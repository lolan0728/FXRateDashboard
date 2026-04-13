import Foundation

public protocol CacheStoreProtocol: Sendable {
    func loadSnapshot(pair: String, range: TimeRangePreset) async -> RateSeriesSnapshot?
    func saveSnapshot(_ snapshot: RateSeriesSnapshot) async throws
}

public final class CacheStore: CacheStoreProtocol, @unchecked Sendable {
    private let paths: AppPaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(paths: AppPaths = AppPaths()) {
        self.paths = paths

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func loadSnapshot(pair: String, range: TimeRangePreset) async -> RateSeriesSnapshot? {
        let url = cacheFileURL(pair: pair, range: range)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(RateSeriesSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    public func saveSnapshot(_ snapshot: RateSeriesSnapshot) async throws {
        try paths.ensureDirectoriesExist()
        let data = try encoder.encode(snapshot)
        try data.write(to: cacheFileURL(pair: snapshot.pair, range: snapshot.range), options: .atomic)
    }

    private func cacheFileURL(pair: String, range: TimeRangePreset) -> URL {
        let safePair = pair.replacingOccurrences(of: "[^A-Za-z0-9]+", with: "_", options: .regularExpression)
        return paths.cacheDirectoryURL.appendingPathComponent("\(safePair)_\(range.rawValue.capitalized).json")
    }
}
