import AppKit
import Foundation
import Combine

/// Kernen i OmnitGram: læs markeret tekst → kør LLM-action → erstat det markerede.
/// Alle offentlige metoder kaldes på main-tråden (hotkey-handlers og menu-items
/// dispatches dertil), og alt UI-arbejde hopper eksplicit tilbage til main.
final class SelectionActionCoordinator: ObservableObject {
    enum State {
        case idle
        case working
        case error
    }

    @Published private(set) var state: State = .idle

    private let settingsStore: SettingsStore
    private let preview = PreviewPanelController()
    private var busy = false  // læses/skrives kun på main

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    /// Ret grammatik - kun fejl, aldrig omskrivning.
    func runGrammarFix() {
        run(.fixGrammar)
    }

    /// Optimér sproget - klarere og mere flydende, samme sprog og tone.
    func runImprove() {
        run(.improveLanguage)
    }

    // MARK: - Fælles flow

    private struct FlowError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func run(_ action: TextAction) {
        guard !busy else { return }

        let apiKey = settingsStore.apiKey.trimmingCharacters(in: .whitespaces)
        guard !apiKey.isEmpty else {
            presentAlert("Manglende API-nøgle til \(settingsStore.provider.displayName). Åbn Indstillinger og tilføj den.")
            return
        }

        busy = true
        state = .working
        let service = settingsStore.makeService()
        let wantPreview = settingsStore.showPreview

        Task { [weak self] in
            guard let self else { return }
            var failure: String?
            do {
                guard let selected = await SelectionService.readSelectedText() else {
                    throw FlowError(message: """
                    Kunne ikke læse markeret tekst.

                    1. Har du markeret noget? Markér teksten og prøv igen.
                    2. Har OmnitGram Accessibility-tilladelse? \
                    System Settings → Privacy & Security → Accessibility → slå OmnitGram til, \
                    og genstart appen.
                    """)
                }
                let result = try await service.run(action, on: selected)
                await MainActor.run {
                    if result == selected {
                        // Allerede korrekt - diskret lyd, rør ikke ved teksten.
                        NSSound(named: "Tink")?.play()
                    } else if wantPreview {
                        let title = action == .fixGrammar ? "Grammatik-rettelser" : "Sprogforbedringer"
                        self.preview.show(
                            title: title,
                            original: selected,
                            corrected: result,
                            onAccept: {
                                TextInserter.insert(result)
                                NSSound(named: "Pop")?.play()
                            },
                            onCancel: {}
                        )
                    } else {
                        TextInserter.insert(result)
                        NSSound(named: "Pop")?.play()
                    }
                }
            } catch {
                failure = error.localizedDescription
            }

            let message = failure
            await MainActor.run {
                self.busy = false
                self.state = .idle
                if let message {
                    self.presentAlert(message)
                }
            }
        }
    }

    /// Skal kaldes på main.
    private func presentAlert(_ message: String) {
        state = .error
        let alert = NSAlert()
        alert.messageText = "OmnitGram"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
        state = .idle
    }
}
