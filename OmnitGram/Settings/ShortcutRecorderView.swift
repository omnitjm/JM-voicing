import SwiftUI
import AppKit

/// Klikbar "knap" der viser den nuværende genvej. Når man klikker, går den i
/// "tryk taster…"-mode og fanger næste keyDown med en lokal NSEvent monitor.
/// Esc annullerer, ⌫ rydder.
struct ShortcutRecorderView: View {
    @Binding var shortcut: ShortcutSpec?
    let placeholder: String

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggleRecording) {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "record.circle")
                            .foregroundStyle(.red)
                        Text("Tryk taster…")
                            .foregroundStyle(.primary)
                    } else if let s = shortcut {
                        Text(s.display)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            if isRecording {
                Text("Esc = annullér · ⌫ = ryd")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if shortcut != nil {
                Button(role: .destructive) {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Fjern genvej")
            }
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if isRecording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            DispatchQueue.main.async {
                self.handle(event: event)
            }
            // Sluk eventet så det ikke når frem til text fields i Settings-vinduet.
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }

    private func handle(event: NSEvent) {
        switch Int(event.keyCode) {
        case 53: // Escape - annullér
            stopRecording()
            return
        case 51, 117: // Backspace / Forward Delete - ryd genvej
            shortcut = nil
            stopRecording()
            return
        default: break
        }

        if let new = ShortcutSpec.from(nsEvent: event) {
            shortcut = new
            stopRecording()
        }
        // Hvis ingen modifier var nede ignorer vi - brugeren skal trykke fx ⌃⌥G,
        // ikke bare G alene (ville aktivere hver gang man skrev).
    }
}
