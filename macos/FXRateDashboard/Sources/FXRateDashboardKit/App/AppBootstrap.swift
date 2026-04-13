import Foundation

@MainActor
public final class AppBootstrap: ObservableObject {
    public let mainWidgetViewModel: MainWidgetViewModel
    public let settingsViewModel: SettingsViewModel
    public let menuBarViewModel: MenuBarViewModel
    public let widgetWindowPlacementService: WidgetWindowPlacementService

    private var didStart = false

    public init() {
        let settingsStore = SettingsStore()
        let cacheStore = CacheStore()
        let tokenStore = KeychainTokenStore()
        let wiseRateClient = WiseRateClient()
        let rateQueryMapper = RateQueryMapper()
        let launchAtLoginService = LaunchAtLoginService()
        var initialSettings = settingsStore.loadSynchronously()
        initialSettings.hasStoredToken = tokenStore.hasToken()

        let mainWidgetViewModel = MainWidgetViewModel(
            settingsStore: settingsStore,
            cacheStore: cacheStore,
            wiseRateClient: wiseRateClient,
            rateQueryMapper: rateQueryMapper,
            tokenStore: tokenStore,
            launchAtLoginService: launchAtLoginService,
            initialSettings: initialSettings
        )

        self.mainWidgetViewModel = mainWidgetViewModel
        self.settingsViewModel = SettingsViewModel()
        self.menuBarViewModel = MenuBarViewModel(mainWidgetViewModel: mainWidgetViewModel)
        self.widgetWindowPlacementService = WidgetWindowPlacementService()
    }

    public func configureOpenSettings(_ action: @escaping () -> Void) {
        mainWidgetViewModel.requestOpenSettings = action
    }

    public func start() async {
        guard !didStart else {
            return
        }

        didStart = true
        await mainWidgetViewModel.initialize()
    }

    public func prepareSettingsViewModel() {
        settingsViewModel.load(
            from: mainWidgetViewModel.settings,
            hasToken: mainWidgetViewModel.currentMaskedToken() != nil,
            maskedToken: mainWidgetViewModel.currentMaskedToken()
        )
    }

    public func saveSettings() async -> String? {
        do {
            let settings = try settingsViewModel.buildSettings()
            return await mainWidgetViewModel.applySettings(settings, tokenUpdate: settingsViewModel.resolveTokenUpdate())
        } catch {
            return error.localizedDescription
        }
    }
}
