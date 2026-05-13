import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section("Anthropic API key") {
                SecureField("sk-ant-...", text: $store.anthropicApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Hentes på console.anthropic.com (separat fra Claude Pro / Team subscription).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dictation") {
                Toggle("Polér grammatik & tilpas til min tone", isOn: $store.enableGrammarPolish)
                Text("Til: rå transcription sendes gennem Claude med din tone-prompt. Fra: rå transcription indsættes direkte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Genveje") {
                shortcutRow(
                    symbol: "mic.fill",
                    title: "Diktér (push-to-talk)",
                    description: "Hold tasten nede mens du taler. Slip for at indsætte."
                ) {
                    Picker("", selection: $store.dictationTrigger) {
                        ForEach(DictationTrigger.allCases) { trigger in
                            Text(trigger.display).tag(trigger)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }

                Divider()

                shortcutRow(
                    symbol: "checkmark.seal",
                    title: "Tjek grammatik",
                    description: "Marker tekst i hvilken som helst app, tryk genvejen. Rettet version erstatter den markerede. Ændrer ikke tone eller sprog."
                ) {
                    ShortcutRecorderView(
                        shortcut: $store.grammarShortcut,
                        placeholder: "Klik for at sætte"
                    )
                }

                Divider()

                shortcutRow(
                    symbol: "sparkles",
                    title: "AI-kommando",
                    description: "Marker tekst (eller intet), tryk genvejen. Popup spørger om en kommando som anvendes på det markerede."
                ) {
                    ShortcutRecorderView(
                        shortcut: $store.commandShortcut,
                        placeholder: "Klik for at sætte"
                    )
                }

                HStack {
                    Spacer()
                    Button("Nulstil genveje") {
                        store.resetDictationTrigger()
                        store.resetGrammarShortcut()
                        store.resetCommandShortcut()
                    }
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }

            Section("Setup") {
                Text("Slå macOS' Fn-dictation FRA hvis du bruger Fn til diktering: System Settings → Keyboard → Dictation: Off og Press 🌐 key to: Do Nothing.")
                Text("Tildel tilladelser: System Settings → Privacy & Security → Microphone + Speech Recognition + Accessibility.")
            }
        }
        .padding(20)
        .frame(width: 580)
    }

    @ViewBuilder
    private func shortcutRow<Trailing: View>(
        symbol: String,
        title: String,
        description: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body).fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView().environmentObject(SettingsStore())
}
