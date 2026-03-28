import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferencesStore = AppPreferencesStore.shared
    private lazy var overlayController = OverlayController(preferencesStore: preferencesStore)
    private lazy var hotKeyController = HotKeyController()
    private lazy var settingsWindowController = SettingsWindowController(preferencesStore: preferencesStore)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let statusMenu = NSMenu()
    private let startStopMenuItem = NSMenuItem(title: "Start Drawing", action: #selector(toggleDrawingMode), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        configureStatusItem()
        configureControllers()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func toggleDrawingMode() {
        overlayController.toggleDrawingMode()
        syncMenuState()
    }

    @objc
    private func openSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func clearAndExit() {
        overlayController.clearAndExit()
        syncMenuState()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func configureMenu() {
        startStopMenuItem.target = self
        statusMenu.addItem(startStopMenuItem)

        let clearItem = NSMenuItem(title: "Clear and Exit", action: #selector(clearAndExit), keyEquivalent: "")
        clearItem.target = self
        statusMenu.addItem(clearItem)

        statusMenu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        statusMenu.addItem(settingsItem)

        statusMenu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Highlighter", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        statusMenu.addItem(quitItem)
    }

    private func configureStatusItem() {
        statusItem.button?.title = "Highlighter"
        statusItem.button?.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        statusItem.menu = statusMenu
    }

    private func configureControllers() {
        hotKeyController.onTrigger = { [weak self] in
            self?.toggleDrawingMode()
        }

        overlayController.onStateChange = { [weak self] in
            self?.syncMenuState()
        }

        hotKeyController.updateRegistration(with: preferencesStore.preferences.hotKey)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: AppPreferencesStore.didChangeNotification,
            object: preferencesStore
        )

        syncMenuState()
    }

    @objc
    private func preferencesDidChange() {
        hotKeyController.updateRegistration(with: preferencesStore.preferences.hotKey)
        syncMenuState()
    }

    private func syncMenuState() {
        startStopMenuItem.title = overlayController.isPresentingOverlay ? "Clear and Exit" : "Start Drawing"
        startStopMenuItem.toolTip = preferencesStore.preferences.hotKey.displayString
    }
}
