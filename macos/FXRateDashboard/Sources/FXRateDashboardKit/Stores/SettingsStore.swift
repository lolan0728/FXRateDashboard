import Foundation

public protocol SettingsStoreProtocol: Sendable {
    func load() async throws -> AppSettings
    func save(_ settings: AppSettings) async throws
}

public final class SettingsStore: SettingsStoreProtocol, @unchecked Sendable {
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

    public func load() async throws -> AppSettings {
        let url = paths.settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppSettings().normalized()
        }

        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppSettings.self, from: data).normalized()
        } catch is DecodingError {
            return AppSettings().normalized()
        }
    }

    public func save(_ settings: AppSettings) async throws {
        try paths.ensureDirectoriesExist()
        let data = try encoder.encode(settings.normalized())
        try data.write(to: paths.settingsFileURL, options: .atomic)
    }
}
