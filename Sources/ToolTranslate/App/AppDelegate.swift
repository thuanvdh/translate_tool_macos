import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var coordinator: AppCoordinator?
    private var shortcutManager: ShortcutManager?

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        let keychainStore = KeychainStore()
        let engine = OpenAITranslationEngine(apiKeyProvider: {
            try keychainStore.loadAPIKey()
        })
        let translationService = TranslationService(engine: engine)
        let popup = TranslationPopupWindowController()
        let settings = SettingsWindowController(keychainStore: keychainStore)
        let selection = SelectionCaptureService()

        let coordinator = AppCoordinator(
            selectionCaptureService: selection,
            translationService: translationService,
            popupWindowController: popup,
            settingsWindowController: settings
        )
        self.coordinator = coordinator

        setupStatusItem()
        setupShortcut(coordinator: coordinator)
    }

    @MainActor
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "VI"

        let menu = NSMenu()
        menu.addItem(makeMenuItem(title: "Translate Selection", action: #selector(translateSelection), keyEquivalent: ""))
        menu.addItem(makeMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    private func makeMenuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @MainActor
    private func setupShortcut(coordinator: AppCoordinator) {
        let manager = ShortcutManager {
            Task { @MainActor in
                coordinator.translateSelection()
            }
        }

        do {
            try manager.register(shortcut: .default)
        } catch {
            NSLog("Shortcut registration failed: \(error.localizedDescription)")
        }

        shortcutManager = manager
    }

    @MainActor
    @objc private func translateSelection() {
        coordinator?.translateSelection()
    }

    @MainActor
    @objc private func showSettings() {
        coordinator?.showSettings()
    }

    @MainActor
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
