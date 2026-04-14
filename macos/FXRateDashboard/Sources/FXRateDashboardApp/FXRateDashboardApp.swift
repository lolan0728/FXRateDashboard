import AppKit
import FXRateDashboardKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var shutdownHandler: (() -> Void)?
    var openSettingsHandler: (() -> Void)?
    var syncWindowVisibilityHandler: ((Bool) -> Void)?
    private weak var settingsMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        shutdownHandler?()
    }

    func applicationDidHide(_ notification: Notification) {
        syncWindowVisibilityHandler?(false)
    }

    func applicationDidUnhide(_ notification: Notification) {
        syncWindowVisibilityHandler?(true)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu(title: "")

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.isEnabled = openSettingsHandler != nil
        menu.addItem(settingsItem)

        return menu
    }

    func configureMenuActions(openSettings: @escaping () -> Void, syncWindowVisibility: @escaping (Bool) -> Void) {
        openSettingsHandler = openSettings
        syncWindowVisibilityHandler = syncWindowVisibility
        settingsMenuItem?.isEnabled = true
    }

    @objc private func openSettings() {
        openSettingsHandler?()
    }

    @objc private func hideApplication() {
        NSApp.hide(nil)
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "FX Rate Dashboard")

        let aboutItem = NSMenuItem(title: "About FX Rate Dashboard", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.isEnabled = openSettingsHandler != nil
        self.settingsMenuItem = settingsItem
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(title: "Hide FX Rate Dashboard", action: #selector(hideApplication), keyEquivalent: "h")
        hideItem.target = self
        hideItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(hideItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit FX Rate Dashboard", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private let aboutWindowController = AboutWindowController()

    @objc private func showAboutPanel() {
        aboutWindowController.show()
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
            MainWidgetSceneView(bootstrap: bootstrap, appDelegate: appDelegate) {
                appDelegate.shutdownHandler = {
                    bootstrap.widgetWindowPlacementService.persistCurrentWindowPosition()
                    bootstrap.mainWidgetViewModel.shutdown()
                }
            } openSettings: {
                settingsWindowController.show(bootstrap: bootstrap)
            }
        }
        .defaultSize(
            width: bootstrap.mainWidgetViewModel.metrics.size.width,
            height: bootstrap.mainWidgetViewModel.metrics.size.height
        )
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
    let appDelegate: AppDelegate
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
            appDelegate.configureMenuActions(
                openSettings: openSettings,
                syncWindowVisibility: { isVisible in
                    bootstrap.mainWidgetViewModel.setWindowVisible(isVisible)
                }
            )
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
