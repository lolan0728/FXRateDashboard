import Foundation

public struct AppPaths: Sendable {
    public let applicationSupportDirectory: URL
    public let settingsFileURL: URL
    public let cacheDirectoryURL: URL

    public init(
        applicationSupportDirectory: URL,
        settingsFileURL: URL,
        cacheDirectoryURL: URL
    ) {
        self.applicationSupportDirectory = applicationSupportDirectory
        self.settingsFileURL = settingsFileURL
        self.cacheDirectoryURL = cacheDirectoryURL
    }

    public init(fileManager: FileManager = .default) {
        let baseDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("FXRateDashboard", isDirectory: true)

        let cacheDirectory = baseDirectory.appendingPathComponent("cache", isDirectory: true)

        self.applicationSupportDirectory = baseDirectory
        self.settingsFileURL = baseDirectory.appendingPathComponent("settings.json")
        self.cacheDirectoryURL = cacheDirectory
    }

    public func ensureDirectoriesExist(fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
    }
}
