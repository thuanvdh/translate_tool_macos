import AppKit

enum PopupState: Equatable {
    case loading(String)
    case result(String)
    case error(String)
    case input(prompt: String)
}

final class TranslationPopupViewController: NSViewController {
    var onSubmitInput: ((String) -> Void)?
    var onCopy: ((String) -> Void)?

    private let stack = NSStackView()
    private let textView = NSTextView()
    private let inputField = NSTextField()
    private let primaryButton = NSButton(title: "Copy", target: nil, action: nil)
    private var currentText = ""

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 0, height: 0)

        inputField.placeholderString = "Paste text to translate"
        inputField.target = self
        inputField.action = #selector(submitInput)

        primaryButton.target = self
        primaryButton.action = #selector(copyCurrentText)

        stack.addArrangedSubview(textView)
        stack.addArrangedSubview(inputField)
        stack.addArrangedSubview(primaryButton)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])

        render(.loading("Ready"))
    }

    func render(_ state: PopupState) {
        switch state {
        case .loading(let message):
            currentText = message
            textView.string = message
            inputField.isHidden = true
            primaryButton.isHidden = true
        case .result(let translation):
            currentText = translation
            textView.string = translation
            inputField.isHidden = true
            primaryButton.title = "Copy"
            primaryButton.isHidden = false
        case .error(let message):
            currentText = message
            textView.string = message
            inputField.isHidden = true
            primaryButton.isHidden = true
        case .input(let prompt):
            currentText = ""
            textView.string = prompt
            inputField.stringValue = ""
            inputField.isHidden = false
            primaryButton.title = "Translate"
            primaryButton.isHidden = false
        }
    }

    @objc private func submitInput() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSubmitInput?(text)
    }

    @objc private func copyCurrentText() {
        if inputField.isHidden {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(currentText, forType: .string)
            onCopy?(currentText)
        } else {
            submitInput()
        }
    }
}
