import AppKit
import Foundation
import Combine

/// Kernen i OmnitGram: læs markeret tekst → kør LLM-action → erstat det markerede.
@MainActor
final class SelectionActionCoordinator: ObservableObject {
    enum State {
        case idle
        case working
        case error
    }

    @Published private(set) var state: State = .idle

    private let settingsStore: SettingsStore
    private var busy = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    /// ⌃⌥G - ret grammatik (kun fejl, aldrig omskrivning).
    func runGrammarFix() {
        run(action: .fixGrammar)
    }

    /// ⌃⌥O - optimér sproget (klarere og mere flydende, samme sprog og tone).
    func runImprove() {
        run(action: .improveLanguage)
    }

    // MARK: - Fælles flow

    private func run(action: TextAction) {
        // Ignorér dobbelt-tryk mens vi allerede arbejder.
        guard !busy else { return }

        Task { @MainActor in
            guard !settingsStore.apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
                presentAlert("Manglende API-nøgle til \(settingsStore.provider.displayName). Åbn Indstillinger og tilføj den.")
                return
            }

            guard let selected = await SelectionService.readSelectedText() else {
                presentAlert("Marker først den tekst du vil have behandlet, og prøv igen.")
                return
            }

            busy = true
            state = .working
            defer {
                busy = false
                if state == .working { state = .idle }
            }

            do {
                let service = settingsStore.makeService()
                let result = try await service.run(action, on: selected)

                if result == selected {
                    // Ingen ændringer nødvendige - diskret lyd, rør ikke ved teksten.
                    NSSound(named: "Tink")?.play()
                    return
                }

                TextInserter.insert(result)
                NSSound(named: "Pop")?.play()
            } catch {
                presentAlert(error.localizedDescription)
            }
        }
    }

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
