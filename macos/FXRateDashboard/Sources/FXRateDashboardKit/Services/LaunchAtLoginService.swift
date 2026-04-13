import Foundation
import ServiceManagement

public protocol LaunchAtLoginServiceProtocol: Sendable {
    func setEnabled(_ enabled: Bool) async throws
}

public struct LaunchAtLoginService: LaunchAtLoginServiceProtocol {
    public init() {}

    public func setEnabled(_ enabled: Bool) async throws {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await SMAppService.mainApp.unregister()
            }
        } catch {
            // Some local/dev builds are not eligible for login items.
        }
    }
}
