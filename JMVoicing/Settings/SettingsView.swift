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
                    symbol: "wand.and.stars",
                    title: "Improve (samme logik, bedre formulering)",
                    description: "Marker tekst, tryk genvejen. Claude strammer formuleringen op uden at ændre mening, stil eller sprog. Virker på dansk og engelsk."
                ) {
                    ShortcutRecorderView(
                        shortcut: $store.improveShortcut,
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
                        store.resetImproveShortcut()
                        store.resetCommandShortcut()
                    }
                    .controlSize(.small)
                }
                .padding(.top, 4)
            }

            Section("Setup - Tilladelser") {
                permissionRow(
                    title: "Mikrofon",
                    description: "Bruges til at høre dig diktere.",
                    status: micStatus,
                    primaryButton: {
                        if micStatus == .notDetermined {
                            PermissionsService.requestMicrophone { _ in refreshPermissions() }
                        } else {
                            PermissionsService.openMicrophoneSettings()
                        }
                    },
                    primaryLabel: micStatus == .notDetermined ? "Spørg om adgang" : "Åbn System Settings"
                )

                Divider()

                permissionRow(
                    title: "Speech Recognition",
                    description: "On-device transcription af tale til tekst.",
                    status: speechStatus,
                    primaryButton: {
                        if speechStatus == .notDetermined {
                            PermissionsService.requestSpeech { _ in refreshPermissions() }
                        } else {
                            PermissionsService.openSpeechSettings()
                        }
                    },
                    primaryLabel: speechStatus == .notDetermined ? "Spørg om adgang" : "Åbn System Settings"
                )

                Divider()

                permissionRow(
                    title: "Accessibility",
                    description: "Nødvendig for at lytte efter dictation- og tekst-genvejene og indsætte tekst i andre apps.",
                    status: accessibilityStatus,
                    primaryButton: {
                        // requestAccessibility prompter første gang. Hvis allerede afvist
                        // åbner vi System Settings så brugeren kan slå Gramchek til manuelt.
                        if accessibilityStatus == .denied {
                            PermissionsService.openAccessibilitySettings()
                        } else {
                            PermissionsService.requestAccessibility()
                            refreshPermissions()
                        }
                    },
                    primaryLabel: accessibilityStatus == .granted ? "Åbn System Settings" : "Aktivér"
                )

                HStack {
                    Spacer()
                    Button("Tjek status igen") { refreshPermissions() }
                        .controlSize(.small)
                }
            }

            Section("Setup - macOS Fn-dictation") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16))
                        .foregroundStyle(.tint)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Slå macOS' egen Fn-dictation FRA")
                            .font(.body).fontWeight(.medium)
                        Text("Hvis du bruger Fn som push-to-talk: Keyboard → Dictation: Off, og Press 🌐 key to: Do Nothing. Ellers stjæler systemet tasten.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Åbn Keyboard Settings") {
                        PermissionsService.openKeyboardSettings()
                    }
                    .controlSize(.regular)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(20)
        .frame(width: 580)
        .onAppear { refreshPermissions() }
    }

    // MARK: - Permission state

    @State private var micStatus: PermissionStatus = .notDetermined
    @State private var speechStatus: PermissionStatus = .notDetermined
    @State private var accessibilityStatus: PermissionStatus = .notDetermined

    private func refreshPermissions() {
        micStatus = PermissionsService.microphoneStatus()
        speechStatus = PermissionsService.speechStatus()
        accessibilityStatus = PermissionsService.accessibilityStatus()
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        description: String,
        status: PermissionStatus,
        primaryButton: @escaping () -> Void,
        primaryLabel: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: status.symbol)
                .font(.system(size: 16))
                .foregroundStyle(statusColor(status))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.body).fontWeight(.medium)
                    Text(status.label)
                        .font(.caption)
                        .foregroundStyle(statusColor(status))
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(primaryLabel, action: primaryButton)
                .controlSize(.regular)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted: return .green
        case .denied: return .red
        case .notDetermined: return .secondary
        }
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
