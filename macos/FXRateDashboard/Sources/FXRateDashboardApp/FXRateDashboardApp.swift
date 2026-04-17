import AppKit
import FXRateDashboardKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var shutdownHandler: (() -> Void)?
    var openSettingsHandler: (() -> Void)?
    var toggleClickThroughHandler: (() -> Void)?
    var clickThroughStateProvider: (() -> Bool)?
    var syncWindowVisibilityHandler: ((Bool) -> Void)?
    private weak var settingsMenuItem: NSMenuItem?
    private weak var clickThroughMenuItem: NSMenuItem?

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
        settingsItem.image = menuSymbol("gearshape")
        menu.addItem(settingsItem)

        let clickThroughItem = NSMenuItem(title: "Click Through", action: #selector(toggleClickThrough), keyEquivalent: "")
        clickThroughItem.target = self
        clickThroughItem.isEnabled = toggleClickThroughHandler != nil
        clickThroughItem.image = clickThroughMenuImage(isEnabled: clickThroughStateProvider?() ?? false)
        menu.addItem(clickThroughItem)

        return menu
    }

    func configureMenuActions(
        openSettings: @escaping () -> Void,
        toggleClickThrough: @escaping () -> Void,
        clickThroughState: @escaping () -> Bool,
        syncWindowVisibility: @escaping (Bool) -> Void
    ) {
        openSettingsHandler = openSettings
        toggleClickThroughHandler = toggleClickThrough
        clickThroughStateProvider = clickThroughState
        syncWindowVisibilityHandler = syncWindowVisibility
        settingsMenuItem?.isEnabled = true
        clickThroughMenuItem?.isEnabled = true
        updateClickThroughMenuState()
    }

    @objc private func openSettings() {
        openSettingsHandler?()
    }

    @objc private func hideApplication() {
        NSApp.hide(nil)
    }

    @objc private func toggleClickThrough() {
        toggleClickThroughHandler?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.updateClickThroughMenuState()
        }
    }

    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateClickThroughMenuState()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "FX Rate Dashboard")
        appMenu.delegate = self

        let aboutItem = NSMenuItem(title: "About FX Rate Dashboard", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = menuSymbol("info.circle")
        appMenu.addItem(aboutItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.isEnabled = openSettingsHandler != nil
        settingsItem.image = menuSymbol("gearshape")
        self.settingsMenuItem = settingsItem
        appMenu.addItem(settingsItem)

        let clickThroughItem = NSMenuItem(title: "Click Through", action: #selector(toggleClickThrough), keyEquivalent: "t")
        clickThroughItem.target = self
        clickThroughItem.keyEquivalentModifierMask = [.command, .shift]
        clickThroughItem.isEnabled = toggleClickThroughHandler != nil
        self.clickThroughMenuItem = clickThroughItem
        appMenu.addItem(clickThroughItem)

        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(title: "Hide FX Rate Dashboard", action: #selector(hideApplication), keyEquivalent: "h")
        hideItem.target = self
        hideItem.keyEquivalentModifierMask = [.command]
        hideItem.image = menuSymbol("eye.slash")
        appMenu.addItem(hideItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit FX Rate Dashboard", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = menuSymbol("xmark.square")
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private let aboutWindowController = AboutWindowController()

    @objc private func showAboutPanel() {
        aboutWindowController.show()
    }

    private func updateClickThroughMenuState() {
        let isEnabled = clickThroughStateProvider?() ?? false
        clickThroughMenuItem?.image = clickThroughMenuImage(isEnabled: isEnabled)
    }

    private func menuSymbol(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private func clickThroughMenuImage(isEnabled: Bool) -> NSImage? {
        guard isEnabled else {
            return menuSymbol("circle")
        }

        return menuSymbol("checkmark")
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
                toggleClickThrough: {
                    Task {
                        await bootstrap.mainWidgetViewModel.toggleClickThrough()
                    }
                },
                clickThroughState: {
                    bootstrap.mainWidgetViewModel.isClickThroughEnabled
                },
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
