import AppKit

final class TranslationPopupWindowController: NSWindowController {
    let popupViewController = TranslationPopupViewController()

    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = popupViewController
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(state: PopupState, near point: NSPoint) {
        popupViewController.render(state)
        let origin = NSPoint(x: point.x + 12, y: point.y - 200)
        window?.setFrameOrigin(origin)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(state: PopupState) {
        popupViewController.render(state)
    }
}
