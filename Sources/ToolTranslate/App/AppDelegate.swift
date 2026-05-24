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

        setupMainMenu()
        setupStatusItem()
        setupShortcut(coordinator: coordinator)
    }

    @MainActor
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(makeMenuItem(title: "Quit Tool Translate", action: #selector(quit), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @MainActor
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "T"

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

        let shortcut = AppShortcut.load() ?? .default
        do {
            try manager.register(shortcut: shortcut)
        } catch {
            NSLog("Shortcut registration failed: \(error.localizedDescription)")
        }

        shortcutManager = manager

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShortcutChange),
            name: .appShortcutDidChange,
            object: nil
        )
    }

    @objc @MainActor
    private func handleShortcutChange() {
        let shortcut = AppShortcut.load() ?? .default
        do {
            try shortcutManager?.register(shortcut: shortcut)
            NSLog("Successfully re-registered custom shortcut: \(shortcut.displayName)")
        } catch {
            NSLog("Failed to register new shortcut: \(error.localizedDescription)")
        }
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
