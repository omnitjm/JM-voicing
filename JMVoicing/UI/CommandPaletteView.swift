import SwiftUI

/// Lille Raycast-agtig popup hvor brugeren skriver en kommando til den markerede tekst.
struct CommandPaletteView: View {
    let selectedText: String?
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var command: String = ""
    @State private var isSubmitting: Bool = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text(selectedText == nil ? "JM Voicing - kommando" : "Bearbejd markeret tekst")
                    .font(.headline)
                Spacer()
                Text("⏎ kør   esc luk")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let sel = selectedText {
                ScrollView {
                    Text(sel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 110)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }

            TextField("Hvad skal der ske? Fx: svar høfligt nej, oversæt til engelsk, gør kortere…",
                      text: $command, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...4)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .focused($fieldFocused)
                .disabled(isSubmitting)
                .onSubmit(submit)

            if isSubmitting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Claude tænker…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(width: 520)
        .background(.regularMaterial)
        .onAppear { fieldFocused = true }
        .onExitCommand(perform: onCancel)
    }

    private func submit() {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        onSubmit(trimmed)
    }
}
