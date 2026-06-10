import AppKit
import Foundation

/// Håndterer de to ikke-dictation features: Grammar check og Inline AI Command.
/// Begge tager udgangspunkt i den markerede tekst.
@MainActor
final class SelectionActionCoordinator {
    private let settingsStore: SettingsStore
    private let palette = CommandPaletteController()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    // MARK: - Grammar check

    /// Læs markeret tekst, kør grammar-check, indsæt rettet tekst i stedet.
    nonisolated func runGrammarCheck() {
        Task { @MainActor in
            guard !settingsStore.anthropicApiKey.isEmpty else {
                presentAlert("Manglende Anthropic API key. Åbn Indstillinger og tilføj den.")
                return
            }
            guard let selected = await SelectionService.readSelectedText() else {
                presentAlert("Marker først den tekst du vil have grammatik-tjekket.")
                return
            }

            do {
                let service = GrammarCheckService(apiKey: settingsStore.anthropicApiKey)
                let corrected = try await service.check(text: selected)
                if corrected == selected {
                    NSSound(named: "Tink")?.play()
                    return
                }
                TextInserter.insert(corrected)
                NSSound(named: "Pop")?.play()
            } catch {
                presentAlert(error.localizedDescription)
            }
        }
    }

    // MARK: - One-press Improve

    /// Læs markeret tekst, kør "Improve clarity"-preset, indsæt forbedret tekst i stedet.
    /// Ét tastetryk, ingen palette - samme UX som ⌃⌥G.
    nonisolated func runImprove() {
        Task { @MainActor in
            guard !settingsStore.anthropicApiKey.isEmpty else {
                presentAlert("Manglende Anthropic API key. Åbn Indstillinger og tilføj den.")
                return
            }
            guard let selected = await SelectionService.readSelectedText() else {
                presentAlert("Marker først den tekst du vil have forbedret.")
                return
            }

            do {
                let service = PresetCommandService(apiKey: settingsStore.anthropicApiKey)
                let improved = try await service.run(preset: .improveClarity, text: selected)
                if improved == selected {
                    NSSound(named: "Tink")?.play()
                    return
                }
                TextInserter.insert(improved)
                NSSound(named: "Pop")?.play()
            } catch {
                presentAlert(error.localizedDescription)
            }
        }
    }

    // MARK: - Inline AI Command

    /// Åbn palette der spørger efter en kommando på den markerede tekst.
    nonisolated func runInlineCommand() {
        Task { @MainActor in
            guard !settingsStore.anthropicApiKey.isEmpty else {
                presentAlert("Manglende Anthropic API key. Åbn Indstillinger og tilføj den.")
                return
            }
            let selected = await SelectionService.readSelectedText()
            palette.show(
                selectedText: selected,
                onSubmit: { [weak self] command in
                    self?.executeCommand(command, on: selected)
                },
                onPreset: { [weak self] preset in
                    self?.executePreset(preset, on: selected)
                },
                onCancel: {}
            )
        }
    }

    private func executeCommand(_ command: String, on selectedText: String?) {
        Task { @MainActor in
            do {
                let service = InlineCommandService(apiKey: settingsStore.anthropicApiKey)
                let result = try await service.run(command: command, selectedText: selectedText)
                guard !result.isEmpty else { return }
                TextInserter.insert(result)
                NSSound(named: "Pop")?.play()
            } catch {
                presentAlert(error.localizedDescription)
            }
        }
    }

    private func executePreset(_ preset: PresetCommand, on selectedText: String?) {
        Task { @MainActor in
            guard let text = selectedText, !text.isEmpty else {
                presentAlert("Marker først den tekst du vil bearbejde.")
                return
            }
            do {
                let service = PresetCommandService(apiKey: settingsStore.anthropicApiKey)
                let result = try await service.run(preset: preset, text: text)
                guard !result.isEmpty else { return }
                if result == text {
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

    // MARK: - Helpers

    private func presentAlert(_ message: String) {
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.messageText = "JM Voicing"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
