import AppKit

@MainActor
final class AppCoordinator {
    private let selectionCaptureService: SelectionCaptureService
    private let translationService: TranslationService
    private let popupWindowController: TranslationPopupWindowController
    private let settingsWindowController: SettingsWindowController

    init(
        selectionCaptureService: SelectionCaptureService,
        translationService: TranslationService,
        popupWindowController: TranslationPopupWindowController,
        settingsWindowController: SettingsWindowController
    ) {
        self.selectionCaptureService = selectionCaptureService
        self.translationService = translationService
        self.popupWindowController = popupWindowController
        self.settingsWindowController = settingsWindowController

        popupWindowController.popupViewController.onSubmitInput = { [weak self] text in
            Task { @MainActor in
                await self?.translate(text: text)
            }
        }
    }

    func translateSelection() {
        let point = selectionCaptureService.currentMouseLocation()

        do {
            let text = try selectionCaptureService.selectedText()
            popupWindowController.show(state: .loading("Translating..."), near: point)
            Task { @MainActor in
                await translate(text: text)
            }
        } catch AppError.accessibilityPermissionMissing {
            _ = selectionCaptureService.hasAccessibilityPermission(prompt: true)
            popupWindowController.show(
                state: .input(prompt: "Accessibility permission is not active yet. Quit and reopen Tool Translate after enabling it, or paste text here and press Return."),
                near: point
            )
        } catch AppError.selectionUnavailable {
            popupWindowController.show(
                state: .input(prompt: "Paste text here and press Return."),
                near: point
            )
        } catch {
            popupWindowController.show(
                state: .error(error.localizedDescription),
                near: point
            )
        }
    }

    func showSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func translate(text: String) async {
        popupWindowController.update(state: .loading("Translating..."))

        do {
            let targetLanguage = UserDefaults.standard.targetLanguage
            let result = try await translationService.translate(text, targetLanguage: targetLanguage)
            popupWindowController.update(state: .result(result.translatedText))
        } catch AppError.missingAPIKey {
            popupWindowController.update(state: .error("Open Settings and save your OpenAI API key."))
            showSettings()
        } catch {
            popupWindowController.update(state: .error(error.localizedDescription))
        }
    }
}
