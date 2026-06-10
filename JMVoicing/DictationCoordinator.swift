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
    private let speech = NativeSpeechService()
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
            let mic = await recorder.requestPermission()
            if !mic {
                notifyError("Mikrofonadgang er ikke givet. Tildel adgang i System Settings.")
                return
            }
            let speechOK = await NativeSpeechService.requestAuthorization()
            if !speechOK {
                notifyError("Speech Recognition er ikke tilladt. Tildel adgang i System Settings → Privacy & Security → Speech Recognition.")
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
            let result = try await speech.transcribe(fileURL: url)
            recorder.cleanup(url: url)

            var output = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            if settingsStore.enableGrammarPolish && !output.isEmpty {
                state = .processing
                let claude = ClaudeService(apiKey: settingsStore.anthropicApiKey)
                output = try await claude.polish(text: output, language: result.language)
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
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.messageText = "Gramchek"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
        state = .idle
    }
}
