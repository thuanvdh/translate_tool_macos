import AppKit
import Carbon

extension Notification.Name {
    static let appShortcutDidChange = Notification.Name("appShortcutDidChange")
}

final class SettingsWindowController: NSWindowController {
    private let apiKeyField = NSSecureTextField()
    private let shortcutRecorder = ShortcutRecorderButton()
    private let languagePopUp = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private let keychainStore: KeychainStore

    init(keychainStore: KeychainStore) {
        self.keychainStore = keychainStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tool Translate Settings"
        super.init(window: window)
        window.contentView = makeContentView()
        loadSavedKey()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func makeContentView() -> NSView {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        apiKeyField.placeholderString = "OpenAI API key"

        let saveButton = NSButton(title: "Save API Key", target: self, action: #selector(saveAPIKey))
        
        let shortcutRow = NSStackView()
        shortcutRow.orientation = .horizontal
        shortcutRow.spacing = 8
        shortcutRow.distribution = .fill
        
        let shortcutText = NSTextField(labelWithString: "Translation Shortcut:")
        shortcutText.font = NSFont.boldSystemFont(ofSize: 13)
        
        shortcutRow.addArrangedSubview(shortcutText)
        shortcutRow.addArrangedSubview(shortcutRecorder)
        
        shortcutRecorder.onShortcutChanged = { shortcut in
            shortcut.save()
            NotificationCenter.default.post(name: .appShortcutDidChange, object: nil)
        }

        let languageRow = NSStackView()
        languageRow.orientation = .horizontal
        languageRow.spacing = 8
        languageRow.distribution = .fill

        let languageText = NSTextField(labelWithString: "Target Language:")
        languageText.font = NSFont.boldSystemFont(ofSize: 13)

        languagePopUp.target = self
        languagePopUp.action = #selector(languageChanged)

        for lang in TargetLanguage.allCases {
            languagePopUp.addItem(withTitle: lang.displayName)
            languagePopUp.lastItem?.representedObject = lang.rawValue
        }

        let savedLang = UserDefaults.standard.targetLanguage
        if let index = TargetLanguage.allCases.firstIndex(of: savedLang) {
            languagePopUp.selectItem(at: index)
        }

        languageRow.addArrangedSubview(languageText)
        languageRow.addArrangedSubview(languagePopUp)

        let privacyText = NSTextField(labelWithString: "Privacy: selected text is sent to OpenAI for translation. This app does not store history or cache translations.")
        privacyText.lineBreakMode = .byWordWrapping
        privacyText.maximumNumberOfLines = 3

        root.addArrangedSubview(NSTextField(labelWithString: "OpenAI API Key"))
        root.addArrangedSubview(apiKeyField)
        root.addArrangedSubview(saveButton)
        root.addArrangedSubview(shortcutRow)
        root.addArrangedSubview(languageRow)
        root.addArrangedSubview(privacyText)
        root.addArrangedSubview(statusLabel)

        return root
    }

    @objc private func languageChanged() {
        if let rawValue = languagePopUp.selectedItem?.representedObject as? String,
           let selectedLang = TargetLanguage(rawValue: rawValue) {
            UserDefaults.standard.targetLanguage = selectedLang
        }
    }

    private func loadSavedKey() {
        do {
            if let key = try keychainStore.loadAPIKey(), !key.isEmpty {
                apiKeyField.stringValue = key
            }
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func saveAPIKey() {
        do {
            try keychainStore.saveAPIKey(apiKeyField.stringValue)
            statusLabel.stringValue = "API key saved."
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var isRecording = false {
        didSet {
            updateButtonState()
        }
    }
    
    private var activeShortcut: AppShortcut? {
        didSet {
            updateButtonState()
        }
    }
    
    var onShortcutChanged: ((AppShortcut) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.bezelStyle = .rounded
        self.setButtonType(.momentaryPushIn)
        self.activeShortcut = AppShortcut.load() ?? .default
        updateButtonState()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private func updateButtonState() {
        if isRecording {
            self.title = "Recording... Press keys"
            self.highlight(true)
        } else {
            self.title = activeShortcut?.displayName ?? "Click to record"
            self.highlight(false)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        setupEventMonitor()
    }
    
    private func cancelRecording() {
        isRecording = false
        removeEventMonitor()
    }
    
    private var eventMonitor: Any?
    
    private func setupEventMonitor() {
        removeEventMonitor()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRecording else { return event }
            
            let keyCode = event.keyCode
            
            if keyCode == 53 { // Escape
                self.cancelRecording()
                return nil
            }
            
            let flags = event.modifierFlags
            var modifiers: AppShortcut.Modifiers = []
            if flags.contains(.command) { modifiers.insert(.command) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            
            // Require at least one modifier key
            if modifiers.isEmpty {
                return nil
            }
            
            let newShortcut = AppShortcut(keyCode: UInt32(keyCode), modifiers: modifiers)
            self.activeShortcut = newShortcut
            self.isRecording = false
            self.removeEventMonitor()
            
            self.onShortcutChanged?(newShortcut)
            return nil
        }
    }
    
    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    deinit {
        removeEventMonitor()
    }
}
