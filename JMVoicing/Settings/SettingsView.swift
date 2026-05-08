import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section("Anthropic API key") {
                SecureField("sk-ant-...", text: $store.anthropicApiKey)
                    .textFieldStyle(.roundedBorder)
                Text("Bruges til at rette grammatik og tilpasse til din tone. Hentes på console.anthropic.com (separat fra Claude Pro/Team subscription).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Behandling") {
                Toggle("Polér grammatik & tilpas til min tone", isOn: $store.enableGrammarPolish)
                Text("Fra: kun rå transcription. Til: bliver kørt gennem Claude med din tone-prompt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Sådan virker det") {
                Text("• Tale → tekst sker on-device med macOS' indbyggede Speech Recognition (gratis, virker offline).")
                Text("• Tekst → poleret tekst sker via Claude API.")
                Text("• Hold Fn / Globus for at diktere. Slip for at indsætte teksten ved markøren.")
                Text("Husk: Slå macOS' indbyggede Fn-dictation fra under System Settings → Keyboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}

#Preview {
    SettingsView().environmentObject(SettingsStore())
}
