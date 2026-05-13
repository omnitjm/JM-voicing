import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section("Anthropic API key") {
                SecureField("sk-ant-...", text: $store.anthropicApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Hentes på console.anthropic.com (separat fra Claude Pro / Team subscription - kræver eget betalingsmiddel).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dictation") {
                Toggle("Polér grammatik & tilpas til min tone", isOn: $store.enableGrammarPolish)
                Text("Til: Whisper-output sendes gennem Claude med din tone-prompt. Fra: rå transcription indsættes direkte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Genveje") {
                shortcutRow(symbol: "mic.fill", keys: "Hold Fn / 🌐",
                            title: "Diktér",
                            description: "Optag tale, transcriber og indsæt ved markøren. Polering aktiv hvis slået til ovenfor.")
                Divider()
                shortcutRow(symbol: "checkmark.seal", keys: "⌃ ⌥ G",
                            title: "Tjek grammatik",
                            description: "Marker tekst i hvilken som helst app, tryk genvejen, rettet version indsættes. Ændrer IKKE tone eller sprog - kun stavefejl og grammatik.")
                Divider()
                shortcutRow(symbol: "sparkles", keys: "⌃ ⌥ A",
                            title: "AI-kommando",
                            description: "Marker tekst (eller intet) og tryk genvejen. Skriv fx \"svar høfligt nej\" eller \"oversæt til engelsk\". Resultatet indsættes ved markøren.")
            }

            Section("Setup") {
                Text("Slå macOS' indbyggede Fn-dictation FRA: System Settings → Keyboard → Dictation: Off og Press 🌐 key to: Do Nothing.")
                Text("Tildel tilladelser: System Settings → Privacy & Security → Microphone + Speech Recognition + Accessibility.")
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    @ViewBuilder
    private func shortcutRow(symbol: String, keys: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.body).fontWeight(.medium)
                    Text(keys)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .cornerRadius(4)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView().environmentObject(SettingsStore())
}
