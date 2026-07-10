import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SettingsStore

    var body: some View {
        Form {
            Section("AI-udbyder") {
                Picker("Udbyder", selection: $store.provider) {
                    ForEach(LLMProvider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)

                SecureField("API-nøgle (\(store.provider.keyPlaceholder))", text: $store.apiKey)
                    .textFieldStyle(.roundedBorder)

                Text("Nøglen hentes på \(store.provider.keyHelpURL) og gemmes sikkert i macOS Keychain. Hver udbyder husker sin egen nøgle.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Model", text: $store.model)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                    Button("Standard") { store.resetModel() }
                        .controlSize(.small)
                    Spacer()
                }
                Text("Lad den stå på standard medmindre du ved hvad du gør.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Genveje") {
                shortcutRow(
                    symbol: "checkmark.seal",
                    title: "Ret grammatik",
                    description: "Retter KUN stave- og grammatikfejl. Ændrer aldrig tone, ordvalg eller sprog."
                ) {
                    ShortcutRecorderView(
                        shortcut: $store.grammarShortcut,
                        placeholder: "Klik for at sætte"
                    )
                }

                Divider()

                shortcutRow(
                    symbol: "wand.and.stars",
                    title: "Optimér sproget",
                    description: "Retter fejl OG forbedrer flow og klarhed. Bevarer sprog, tone og alt indhold."
                ) {
                    ShortcutRecorderView(
                        shortcut: $store.improveShortcut,
                        placeholder: "Klik for at sætte"
                    )
                }

                HStack {
                    Spacer()
                    Button("Nulstil genveje") { store.resetShortcuts() }
                        .controlSize(.small)
                }
            }

            Section("Sådan bruger du OmnitGram") {
                Text("1. Markér tekst i en hvilken som helst app (Mail, Slack, browser…).")
                Text("2. Tryk genvejen - eller brug menubar-ikonet.")
                Text("3. Den behandlede tekst erstatter automatisk det markerede.")
                Text("Kræver Accessibility-tilladelse: System Settings → Privacy & Security → Accessibility → OmnitGram.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 560)
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
