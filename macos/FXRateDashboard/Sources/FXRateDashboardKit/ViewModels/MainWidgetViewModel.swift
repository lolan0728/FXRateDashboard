import Combine
import CoreGraphics
import Foundation
import SwiftUI

private actor RefreshGate {
    private var isLocked = false

    func tryAcquire() -> Bool {
        guard !isLocked else {
            return false
        }

        isLocked = true
        return true
    }

    func release() {
        isLocked = false
    }
}

@MainActor
public final class MainWidgetViewModel: ObservableObject {
    @Published public private(set) var pairLabel = "USD/CNY"
    @Published public private(set) var currentRateDisplay = "--"
    @Published public private(set) var quoteCurrencyCode = "CNY"
    @Published public private(set) var changeDisplay = "+0.0000"
    @Published public private(set) var changePercentDisplay = "+0.00%"
    @Published public private(set) var statusMessage = "Updated at: --"
    @Published public private(set) var footerSourceText = "Wise"
    @Published public private(set) var activeRange: TimeRangePreset = .day
    @Published public private(set) var chartPoints: [RatePoint] = []
    @Published public private(set) var isOffline = true
    @Published public private(set) var isCompactMode = false
    @Published public private(set) var isWindowVisible = true
    @Published public private(set) var isPositionLocked = false
    @Published public private(set) var isClickThroughEnabled = false
    @Published public private(set) var trendColor = ColorPalette.offlineTrend
    @Published public private(set) var panelBackgroundColor = ColorPalette.panelBackgroundOffline
    @Published public private(set) var chartCardBackgroundColor = ColorPalette.surfaceAltOffline
    @Published public private(set) var accentColor = ColorPalette.accentOffline
    @Published public private(set) var primaryTextColor = ColorPalette.primaryTextOffline
    @Published public private(set) var mutedTextColor = ColorPalette.mutedTextOffline
    @Published public private(set) var statusChipBackgroundColor = ColorPalette.statusChipBackgroundOffline

    public var settings: AppSettings { currentSettings }
    public var metrics: WidgetMetrics { isCompactMode ? .compact : .full }
    public var statusChipText: String { isCompactMode ? RateMath.extractCompactStatusText(statusMessage) : statusMessage }
    public var toggleModeMenuText: String { isCompactMode ? "Restore Full Mode" : "Compact Mode" }
    public var toggleVisibilityMenuText: String { isWindowVisible ? "Hide Window" : "Show Window" }
    public var clickThroughMenuText: String { "Click Through" }

    public var requestOpenSettings: (() -> Void)?

    private let settingsStore: SettingsStoreProtocol
    private let cacheStore: CacheStoreProtocol
    private let wiseRateClient: WiseRateClientProtocol
    private let rateQueryMapper: RateQueryMapperProtocol
    private let tokenStore: TokenStoreProtocol
    private let launchAtLoginService: LaunchAtLoginServiceProtocol
    private let currentRefreshGate = RefreshGate()
    private let historyRefreshGate = RefreshGate()

    private var currentSettings = AppSettings()
    private var snapshot: RateSeriesSnapshot?
    private var currentRateTask: Task<Void, Never>?
    private var historyTask: Task<Void, Never>?
    private var didInitialize = false
    private var lastCompactToggleAt = Date.distantPast

    public init(
        settingsStore: SettingsStoreProtocol,
        cacheStore: CacheStoreProtocol,
        wiseRateClient: WiseRateClientProtocol,
        rateQueryMapper: RateQueryMapperProtocol,
        tokenStore: TokenStoreProtocol,
        launchAtLoginService: LaunchAtLoginServiceProtocol,
        initialSettings: AppSettings = AppSettings()
    ) {
        self.settingsStore = settingsStore
        self.cacheStore = cacheStore
        self.wiseRateClient = wiseRateClient
        self.rateQueryMapper = rateQueryMapper
        self.tokenStore = tokenStore
        self.launchAtLoginService = launchAtLoginService
        self.currentSettings = initialSettings.normalized()
        self.currentSettings.hasStoredToken = tokenStore.hasToken()
        applySettingsToPublishedState()
    }

    public func initialize() async {
        guard !didInitialize else {
            return
        }

        didInitialize = true
        await ensureSettingsLoaded()
        await restoreCachedSnapshot(presentAsOffline: true)

        guard let token = normalizedStoredToken() else {
            await setOfflineState(openSettings: true)
            return
        }

        Task { [weak self] in
            guard let self else {
                return
            }

            await self.bootstrapAndStartPolling(using: token, openSettingsOnFailure: true)
        }
    }

    public func currentMaskedToken() -> String? {
        guard let token = normalizedStoredToken() else {
            return nil
        }

        return SettingsViewModel.maskToken(token)
    }

    public func ensureSettingsLoaded() async {
        do {
            currentSettings = try await settingsStore.load().normalized()
        } catch {
            currentSettings = AppSettings().normalized()
        }

        currentSettings.hasStoredToken = tokenStore.hasToken()
        applySettingsToPublishedState()
    }

    public func updateWindowPosition(x: Double, y: Double, forCompactMode: Bool? = nil) {
        guard !currentSettings.lockPosition else {
            return
        }

        let targetMode = forCompactMode ?? currentSettings.isCompactMode
        setStoredWindowOrigin(x: x, y: y, forCompactMode: targetMode)

        Task {
            try? await settingsStore.save(currentSettings)
        }
    }

    public func setWindowVisible(_ isVisible: Bool) {
        guard isWindowVisible != isVisible else {
            return
        }

        isWindowVisible = isVisible
    }

    public func toggleCompactMode() async {
        let now = Date()
        guard now.timeIntervalSince(lastCompactToggleAt) > 0.35 else {
            return
        }

        lastCompactToggleAt = now
        currentSettings.isCompactMode.toggle()
        isCompactMode = currentSettings.isCompactMode
        try? await settingsStore.save(currentSettings)
    }

    public func toggleClickThrough() async {
        currentSettings.clickThroughEnabled.toggle()
        isClickThroughEnabled = currentSettings.clickThroughEnabled
        try? await settingsStore.save(currentSettings)
    }

    public func setClickThroughEnabled(_ isEnabled: Bool) async {
        guard currentSettings.clickThroughEnabled != isEnabled else {
            return
        }

        currentSettings.clickThroughEnabled = isEnabled
        isClickThroughEnabled = isEnabled
        try? await settingsStore.save(currentSettings)
    }

    public func storedWindowOrigin(forCompactMode: Bool) -> CGPoint? {
        let x: Double?
        let y: Double?

        if forCompactMode {
            x = currentSettings.compactWindowOriginX ?? (currentSettings.isCompactMode ? currentSettings.windowOriginX : nil)
            y = currentSettings.compactWindowOriginY ?? (currentSettings.isCompactMode ? currentSettings.windowOriginY : nil)
        } else {
            x = currentSettings.fullWindowOriginX ?? (!currentSettings.isCompactMode ? currentSettings.windowOriginX : nil)
            y = currentSettings.fullWindowOriginY ?? (!currentSettings.isCompactMode ? currentSettings.windowOriginY : nil)
        }

        guard let x, let y else {
            return nil
        }

        return CGPoint(x: x, y: y)
    }

    public func selectRange(_ range: TimeRangePreset) async {
        guard currentSettings.activeRange != range || snapshot?.range != range else {
            return
        }

        currentSettings.activeRange = range
        activeRange = range
        try? await settingsStore.save(currentSettings)
        await restoreCachedSnapshot(presentAsOffline: isOffline)

        if normalizedStoredToken() != nil {
            await tryRefreshHistory()
        }
    }

    public func applySettings(_ newSettings: AppSettings, tokenUpdate: TokenUpdate) async -> String? {
        let normalized = newSettings.normalized()
        let currentToken = normalizedStoredToken()
        let requestedToken: String?

        switch tokenUpdate {
        case .unchanged:
            requestedToken = currentToken
        case let .set(token):
            requestedToken = SettingsViewModel.normalizeTokenInput(token)
        case .clear:
            requestedToken = nil
        }

        let tokenChanged = currentToken != requestedToken
        let pairChanged = normalized.baseCurrency != currentSettings.baseCurrency ||
            normalized.quoteCurrency != currentSettings.quoteCurrency ||
            normalized.activeRange != currentSettings.activeRange

        if tokenChanged, let requestedToken {
            do {
                _ = try await wiseRateClient.getCurrentRate(
                    source: normalized.baseCurrency,
                    target: normalized.quoteCurrency,
                    token: requestedToken
                )
            } catch {
                return error.localizedDescription
            }
        }

        stopPolling()

        do {
            if tokenChanged {
                if let requestedToken {
                    try tokenStore.saveToken(requestedToken)
                } else {
                    try tokenStore.deleteToken()
                }
            }
        } catch {
            return error.localizedDescription
        }

        currentSettings = normalized
        currentSettings.hasStoredToken = requestedToken != nil

        do {
            try await settingsStore.save(currentSettings)
            try await launchAtLoginService.setEnabled(currentSettings.launchAtStartup)
        } catch {
            return error.localizedDescription
        }

        applySettingsToPublishedState()

        if let snapshot, !pairChanged, !tokenChanged {
            await publishSnapshot(snapshot, footerHint: footerSourceText, presentAsOffline: isOffline)
        } else if pairChanged {
            await restoreCachedSnapshot(presentAsOffline: isOffline)
        }

        guard let requestedToken else {
            await setOfflineState(openSettings: false)
            return nil
        }

        if pairChanged || tokenChanged {
            await bootstrapAndStartPolling(using: requestedToken, openSettingsOnFailure: false)
        } else {
            startPollingLoops()
        }

        return nil
    }

    public func shutdown() {
        stopPolling()
        try? settingsStore.saveSynchronously(currentSettings)
    }

    private func applySettingsToPublishedState() {
        pairLabel = RateMath.displayPairLabel(
            baseAmount: currentSettings.baseAmount,
            baseCurrency: currentSettings.baseCurrency,
            quoteCurrency: currentSettings.quoteCurrency
        )
        quoteCurrencyCode = currentSettings.quoteCurrency
        activeRange = currentSettings.activeRange
        isCompactMode = currentSettings.isCompactMode
        isPositionLocked = currentSettings.lockPosition
        isClickThroughEnabled = currentSettings.clickThroughEnabled
    }

    private func setStoredWindowOrigin(x: Double, y: Double, forCompactMode: Bool) {
        currentSettings.windowOriginX = x
        currentSettings.windowOriginY = y

        if forCompactMode {
            currentSettings.compactWindowOriginX = x
            currentSettings.compactWindowOriginY = y
        } else {
            currentSettings.fullWindowOriginX = x
            currentSettings.fullWindowOriginY = y
        }
    }

    private func restoreCachedSnapshot(presentAsOffline: Bool) async {
        guard let cachedSnapshot = await cacheStore.loadSnapshot(pair: currentSettings.pair, range: currentSettings.activeRange) else {
            return
        }

        var staleSnapshot = cachedSnapshot
        staleSnapshot.isStale = true
        await publishSnapshot(staleSnapshot, footerHint: "Cached", presentAsOffline: presentAsOffline)
    }

    private func bootstrapAndStartPolling(using token: String, openSettingsOnFailure: Bool) async {
        do {
            try await refreshCurrent(using: token)
            startPollingLoops()
            Task { [weak self] in
                guard let self else {
                    return
                }

                do {
                    try await self.refreshHistorical(using: token)
                } catch {
                    await self.markSnapshotStale()
                }
            }
        } catch {
            await setOfflineState(openSettings: openSettingsOnFailure)
        }
    }

    private func startPollingLoops() {
        stopPolling()

        let refreshSeconds = currentSettings.refreshSeconds
        currentRateTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(refreshSeconds))
                guard !Task.isCancelled else { return }
                await self.tryRefreshCurrent()
            }
        }

        historyTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(900))
                guard !Task.isCancelled else { return }
                await self.tryRefreshHistory()
            }
        }
    }

    private func stopPolling() {
        currentRateTask?.cancel()
        historyTask?.cancel()
        currentRateTask = nil
        historyTask = nil
    }

    private func tryRefreshCurrent() async {
        do {
            try await refreshCurrent(using: try tokenOrThrow())
        } catch {
            if case WiseRateClientError.invalidToken = error {
                stopPolling()
                await setOfflineState(openSettings: true)
            } else {
                await markSnapshotStale()
            }
        }
    }

    private func tryRefreshHistory() async {
        do {
            try await refreshHistorical(using: try tokenOrThrow())
        } catch {
            if case WiseRateClientError.invalidToken = error {
                stopPolling()
                await setOfflineState(openSettings: true)
            } else {
                await markSnapshotStale()
            }
        }
    }

    private func refreshCurrent(using token: String) async throws {
        guard await currentRefreshGate.tryAcquire() else {
            return
        }

        defer {
            Task { await currentRefreshGate.release() }
        }

        let currentRate = try await wiseRateClient.getCurrentRate(
            source: currentSettings.baseCurrency,
            target: currentSettings.quoteCurrency,
            token: token
        )

        let merged = RateMath.appendOrReplaceLatest(snapshot?.points ?? [], latestPoint: currentRate)
        let snapshot = RateMath.createSnapshot(
            pair: currentSettings.pair,
            range: currentSettings.activeRange,
            points: merged,
            currentRateOverride: currentRate.rate,
            asOfUTC: currentRate.timestampUTC,
            isStale: false
        )

        try await cacheStore.saveSnapshot(snapshot)
        await publishSnapshot(snapshot, footerHint: "Wise")
    }

    private func refreshHistorical(using token: String) async throws {
        guard await historyRefreshGate.tryAcquire() else {
            return
        }

        defer {
            Task { await historyRefreshGate.release() }
        }

        let query = rateQueryMapper.mapHistoryQuery(currentSettings.activeRange, nowUTC: Date())
        let history = try await wiseRateClient.getHistoricalRates(
            source: currentSettings.baseCurrency,
            target: currentSettings.quoteCurrency,
            token: token,
            fromUTC: query.fromUTC,
            toUTC: query.toUTC,
            group: query.group
        )
        let currentRate = try await wiseRateClient.getCurrentRate(
            source: currentSettings.baseCurrency,
            target: currentSettings.quoteCurrency,
            token: token
        )
        let merged = RateMath.appendOrReplaceLatest(history, latestPoint: currentRate)
        let snapshot = RateMath.createSnapshot(
            pair: currentSettings.pair,
            range: currentSettings.activeRange,
            points: merged,
            currentRateOverride: currentRate.rate,
            asOfUTC: currentRate.timestampUTC,
            isStale: false
        )

        try await cacheStore.saveSnapshot(snapshot)
        await publishSnapshot(snapshot, footerHint: "Wise")
    }

    private func publishSnapshot(_ snapshot: RateSeriesSnapshot, footerHint: String, presentAsOffline: Bool = false) async {
        self.snapshot = snapshot

        let downsampled = RateMath.downsample(snapshot.points, maxPoints: 240)
        let scaledChartPoints = RateMath.scalePoints(downsampled, multiplier: currentSettings.baseAmount)
        let convertedCurrent = snapshot.currentRate * currentSettings.baseAmount
        let convertedChange = snapshot.changeAbsolute * currentSettings.baseAmount

        withAnimation(.easeInOut(duration: 0.5)) {
            pairLabel = RateMath.displayPairLabel(
                baseAmount: currentSettings.baseAmount,
                baseCurrency: currentSettings.baseCurrency,
                quoteCurrency: currentSettings.quoteCurrency
            )
            quoteCurrencyCode = currentSettings.quoteCurrency
            activeRange = snapshot.range
            chartPoints = scaledChartPoints
            currentRateDisplay = RateMath.formatDisplayAmount(convertedCurrent)
            changeDisplay = RateMath.formatSignedAmount(convertedChange)
            changePercentDisplay = "\(snapshot.changePercent > 0 ? "+" : "")\(NSDecimalNumber(decimal: snapshot.changePercent).doubleValue.formatted(.number.precision(.fractionLength(2))))%"
            statusMessage = RateMath.formatUpdatedAt(snapshot.asOfUTC)
            footerSourceText = footerHint
            applyPalette(isOffline: presentAsOffline, changeAbsolute: snapshot.changeAbsolute)
            isOffline = presentAsOffline
        }
    }

    private func markSnapshotStale() async {
        guard var snapshot else {
            await setOfflineState(openSettings: false)
            return
        }

        snapshot.isStale = true
        await publishSnapshot(snapshot, footerHint: "Cached", presentAsOffline: true)
    }

    private func setOfflineState(openSettings: Bool) async {
        withAnimation(.easeInOut(duration: 0.5)) {
            let updatedLabel = snapshot.map { RateMath.formatUpdatedAt($0.asOfUTC) } ?? "Updated at: --"
            statusMessage = updatedLabel
            footerSourceText = "Wise"
            applyPalette(isOffline: true, changeAbsolute: snapshot?.changeAbsolute)
            isOffline = true
        }

        if openSettings {
            requestOpenSettings?()
        }
    }

    private func applyPalette(isOffline: Bool, changeAbsolute: Decimal?) {
        trendColor = isOffline
            ? ColorPalette.offlineTrend
            : (changeAbsolute ?? 0) >= 0 ? ColorPalette.positive : ColorPalette.negative
        panelBackgroundColor = isOffline ? ColorPalette.panelBackgroundOffline : ColorPalette.panelBackgroundOnline
        chartCardBackgroundColor = isOffline ? ColorPalette.surfaceAltOffline : ColorPalette.surfaceAltOnline
        accentColor = isOffline ? ColorPalette.accentOffline : ColorPalette.accentOnline
        primaryTextColor = isOffline ? ColorPalette.primaryTextOffline : ColorPalette.primaryTextOnline
        mutedTextColor = isOffline ? ColorPalette.mutedTextOffline : ColorPalette.mutedTextOnline
        statusChipBackgroundColor = isOffline ? ColorPalette.statusChipBackgroundOffline : ColorPalette.statusChipBackgroundOnline
    }

    private func normalizedStoredToken() -> String? {
        SettingsViewModel.normalizeTokenInput(tokenStore.loadToken())
    }

    private func tokenOrThrow() throws -> String {
        guard let token = normalizedStoredToken() else {
            throw WiseRateClientError.invalidToken
        }

        return token
    }
}
