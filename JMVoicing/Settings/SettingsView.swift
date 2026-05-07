import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section("OpenAI API") {
                SecureField("API key (sk-...)", text: $store.apiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Bruges til både Whisper-transcription og GPT-grammatik. Hentes på platform.openai.com.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Behandling") {
                Toggle("Polér grammatik & tilpas til min tone", isOn: $store.enableGrammarPolish)
                Text("Fra: ren Whisper-transcription. Til: bliver kørt gennem GPT-4o-mini med din tone-prompt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Hotkey") {
                Text("Hold Fn / Globus for at diktere. Slip for at indsætte teksten ved markøren.")
                Text("Husk: Slå macOS' indbyggede Fn-dictation fra under System Settings → Keyboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

#Preview {
    SettingsView().environmentObject(SettingsStore())
}
