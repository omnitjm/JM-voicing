import Foundation
import AppKit
import Combine

/// Holder hele flowet sammen: hotkey → optag → transcribe → polér → indsæt.
@MainActor
final class DictationCoordinator: ObservableObject {
    enum State {
        case idle
        case recording
        case transcribing
        case processing
        case error
    }

    @Published private(set) var state: State = .idle

    private let settingsStore: SettingsStore
    private let recorder = AudioRecorder()
    private var permissionRequested = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    nonisolated func startRecording() {
        Task { @MainActor in await self.beginRecord() }
    }

    nonisolated func stopAndProcess() {
        Task { @MainActor in await self.endRecord() }
    }

    private func beginRecord() async {
        guard state == .idle else { return }

        if !permissionRequested {
            permissionRequested = true
            let granted = await recorder.requestPermission()
            if !granted {
                notifyError("Mikrofonadgang er ikke givet. Tildel adgang i System Settings.")
                return
            }
        }

        do {
            try recorder.start()
            state = .recording
            NSSound(named: "Tink")?.play()
        } catch {
            notifyError("Kunne ikke starte optagelse: \(error.localizedDescription)")
        }
    }

    private func endRecord() async {
        guard state == .recording else { return }
        guard let url = recorder.stop() else {
            state = .idle
            return
        }

        state = .transcribing

        do {
            let whisper = WhisperService(apiKey: settingsStore.apiKey)
            let result = try await whisper.transcribe(fileURL: url)
            recorder.cleanup(url: url)

            var output = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if settingsStore.enableGrammarPolish && !output.isEmpty {
                state = .processing
                let grammar = GrammarService(apiKey: settingsStore.apiKey)
                output = try await grammar.polish(text: output, language: result.language)
            }

            if !output.isEmpty {
                TextInserter.insert(output)
                NSSound(named: "Pop")?.play()
            }
            state = .idle
        } catch {
            recorder.cleanup(url: url)
            notifyError(error.localizedDescription)
        }
    }

    private func notifyError(_ message: String) {
        state = .error
        let alert = NSAlert()
        alert.messageText = "JM Voicing"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
        state = .idle
    }
}
