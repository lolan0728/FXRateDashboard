import AppKit
import FXRateDashboardKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var shutdownHandler: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        shutdownHandler?()
    }
}

@main
struct FXRateDashboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var bootstrap = AppBootstrap()
    private let settingsWindowController = SettingsWindowController()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup(id: "main-widget") {
            MainWidgetSceneView(bootstrap: bootstrap) {
                appDelegate.shutdownHandler = {
                    Task { await bootstrap.mainWidgetViewModel.shutdown() }
                }
            } openSettings: {
                settingsWindowController.show(bootstrap: bootstrap)
            }
        }
        .defaultSize(width: WidgetMetrics.full.size.width, height: WidgetMetrics.full.size.height)
        .windowResizability(.contentSize)

        MenuBarExtra("FX Rate Dashboard", systemImage: "chart.line.uptrend.xyaxis") {
            MenuBarSceneView(bootstrap: bootstrap) {
                settingsWindowController.show(bootstrap: bootstrap)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MainWidgetSceneView: View {
    @ObservedObject var bootstrap: AppBootstrap
    let onReady: () -> Void
    let openSettings: () -> Void

    var body: some View {
        MainWidgetWindowView(
            viewModel: bootstrap.mainWidgetViewModel,
            windowPlacementService: bootstrap.widgetWindowPlacementService,
            openSettings: openSettings,
            quitApplication: { NSApp.terminate(nil) }
        )
        .task {
            bootstrap.configureOpenSettings(openSettings)
            bootstrap.prepareSettingsViewModel()
            await bootstrap.start()
            onReady()
        }
    }
}

private struct MenuBarSceneView: View {
    @ObservedObject var bootstrap: AppBootstrap
    let openSettings: () -> Void

    var body: some View {
        MenuBarMenuView(
            viewModel: bootstrap.menuBarViewModel,
            openSettings: openSettings,
            quitApplication: { NSApp.terminate(nil) }
        )
    }
}
