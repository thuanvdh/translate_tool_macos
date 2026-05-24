import AppKit

final class SettingsWindowController: NSWindowController {
    private let apiKeyField = NSSecureTextField()
    private let shortcutLabel = NSTextField(labelWithString: AppShortcut.default.displayName)
    private let statusLabel = NSTextField(labelWithString: "")
    private let keychainStore: KeychainStore

    init(keychainStore: KeychainStore) {
        self.keychainStore = keychainStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
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
        let shortcutText = NSTextField(labelWithString: "Shortcut")
        let privacyText = NSTextField(labelWithString: "Privacy: selected text is sent to OpenAI for translation. This app does not store history or cache translations.")
        privacyText.lineBreakMode = .byWordWrapping
        privacyText.maximumNumberOfLines = 3

        root.addArrangedSubview(NSTextField(labelWithString: "OpenAI API Key"))
        root.addArrangedSubview(apiKeyField)
        root.addArrangedSubview(saveButton)
        root.addArrangedSubview(shortcutText)
        root.addArrangedSubview(shortcutLabel)
        root.addArrangedSubview(privacyText)
        root.addArrangedSubview(statusLabel)

        return root
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
