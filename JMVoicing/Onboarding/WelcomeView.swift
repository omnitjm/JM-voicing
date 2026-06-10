import SwiftUI
import AppKit

/// Velkomst- og demoskærm. Forklarer hvad app'en kan, viser status på tilladelser
/// og API key, og lader brugeren prøve hver feature uden at skulle ud i andre apps.
struct WelcomeView: View {
    @EnvironmentObject var store: SettingsStore

    let onDismiss: () -> Void

    @State private var micStatus: PermissionStatus = .notDetermined
    @State private var speechStatus: PermissionStatus = .notDetermined
    @State private var accessibilityStatus: PermissionStatus = .notDetermined

    @State private var demoText: String = "Hej kollega, vi mødtes igår og det var rigtigt rart at hilse på dig. jeg ville bare lige sige tak."
    @State private var demoBusy = false
    @State private var demoResult: String?
    @State private var demoError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                featureSection

                Divider()

                statusSection

                Divider()

                trySection

                Divider()

                footer
            }
            .padding(28)
            .frame(maxWidth: 720)
        }
        .frame(width: 720, height: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: refreshStatus)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Velkommen til JM Voicing")
                        .font(.system(size: 26, weight: .bold))
                    Text("Tre globale genveje, én Anthropic API key.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Feature cards

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sådan virker det").font(.title3).fontWeight(.semibold)

            featureRow(
                symbol: "mic.fill",
                tint: .pink,
                shortcut: "Hold \(store.dictationTrigger.display)",
                title: "Diktér",
                howto: "Hold tasten nede mens du taler. Slip → polér via Claude → indsæt ved markøren.",
                example: "\"Hej kan vi mødes onsdag\" → \"Hej, kan vi mødes på onsdag?\""
            )

            featureRow(
                symbol: "checkmark.seal.fill",
                tint: .green,
                shortcut: store.grammarShortcut?.display ?? "Slået fra",
                title: "Correct grammar",
                howto: "Marker tekst i en hvilken som helst app, tryk genvejen. Rettet version erstatter den markerede.",
                example: "Tone og sprog røres ikke - kun stavefejl, grammatik, tegnsætning. Virker på dansk og engelsk."
            )

            featureRow(
                symbol: "wand.and.stars",
                tint: .orange,
                shortcut: store.improveShortcut?.display ?? "Slået fra",
                title: "Improve",
                howto: "Marker tekst, tryk genvejen. Claude strammer formuleringen op uden at ændre mening eller sprog.",
                example: "Samme logik og indhold, bare bedre formuleret. Virker på dansk og engelsk."
            )

            featureRow(
                symbol: "sparkles",
                tint: .purple,
                shortcut: store.commandShortcut?.display ?? "Slået fra",
                title: "AI-kommando",
                howto: "Marker tekst (eller intet), tryk genvejen. Popup spørger om en kommando.",
                example: "\"oversæt til engelsk\" · \"svar høfligt nej\" · \"gør halvt så langt\""
            )
        }
    }

    @ViewBuilder
    private func featureRow(symbol: String, tint: Color, shortcut: String,
                            title: String, howto: String, example: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    Text(shortcut)
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
                Text(howto).font(.callout).foregroundStyle(.primary)
                Text(example).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status").font(.title3).fontWeight(.semibold)

            statusBadge(symbol: store.anthropicApiKey.isEmpty ? "key.slash" : "key.fill",
                        label: "Anthropic API key",
                        ok: !store.anthropicApiKey.isEmpty,
                        hint: store.anthropicApiKey.isEmpty
                            ? "Tilføj i Indstillinger - uden den kan ingen af features virke."
                            : "Indtastet og gemt i Keychain.")

            statusBadge(symbol: "mic", label: "Mikrofon",
                        ok: micStatus == .granted, hint: micStatus.label)
            statusBadge(symbol: "waveform", label: "Speech Recognition",
                        ok: speechStatus == .granted, hint: speechStatus.label)
            statusBadge(symbol: "hand.raised", label: "Accessibility",
                        ok: accessibilityStatus == .granted, hint: accessibilityStatus.label)

            HStack {
                Button("Åbn Indstillinger") {
                    onDismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        if #available(macOS 14, *) {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        } else {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }
                    }
                }
                Button("Tjek status igen") { refreshStatus() }
                    .controlSize(.regular)
                Spacer()
            }
            .padding(.top, 4)
        }
    }

    private func statusBadge(symbol: String, label: String, ok: Bool, hint: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(ok ? .green : .orange)
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 18)
            Text(label).font(.body)
            Text("- \(hint)").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Try AI command in-place

    private var trySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prøv det her").font(.title3).fontWeight(.semibold)
            Text("Skriv eller ret i teksten herunder og lad Claude polere den med din tone (samme pipeline som ⌃⌥G).")
                .font(.caption).foregroundStyle(.secondary)

            TextEditor(text: $demoText)
                .font(.system(size: 13))
                .frame(height: 96)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.3)))

            HStack(spacing: 10) {
                Button {
                    Task { await runDemo() }
                } label: {
                    HStack(spacing: 6) {
                        if demoBusy { ProgressView().controlSize(.small) }
                        Text(demoBusy ? "Claude tænker…" : "Tjek grammatik")
                    }
                }
                .disabled(demoBusy || store.anthropicApiKey.isEmpty)

                if store.anthropicApiKey.isEmpty {
                    Text("Tilføj API key i Indstillinger først")
                        .font(.caption).foregroundStyle(.orange)
                }
                Spacer()
            }

            if let result = demoResult {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resultat:").font(.caption).foregroundStyle(.secondary)
                    Text(result)
                        .font(.system(size: 13))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
            }
            if let error = demoError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func runDemo() async {
        let input = demoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !store.anthropicApiKey.isEmpty else { return }
        demoBusy = true
        demoResult = nil
        demoError = nil
        defer { demoBusy = false }
        do {
            let service = GrammarCheckService(apiKey: store.anthropicApiKey)
            let corrected = try await service.check(text: input)
            demoResult = corrected
        } catch {
            demoError = error.localizedDescription
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { !store.hasSeenWelcome },
                set: { store.hasSeenWelcome = !$0 }
            )) {
                Text("Vis ved opstart").font(.callout)
            }
            .toggleStyle(.checkbox)
            Spacer()
            Button("Luk", action: onDismiss)
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Helpers

    private func refreshStatus() {
        micStatus = PermissionsService.microphoneStatus()
        speechStatus = PermissionsService.speechStatus()
        accessibilityStatus = PermissionsService.accessibilityStatus()
    }
}

#Preview {
    WelcomeView(onDismiss: {})
        .environmentObject(SettingsStore())
}
