import AppKit
import SwiftUI

/// Read-only NSTextView der viser den farvemarkerede diff.
private struct DiffTextView: NSViewRepresentable {
    let attributed: NSAttributedString

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let textView = scroll.documentView as! NSTextView
        textView.textStorage?.setAttributedString(attributed)
    }
}

/// Indholdet af preview-panelet: titel, diff, Indsæt/Annullér.
struct PreviewView: View {
    let title: String
    let diff: NSAttributedString
    let onAccept: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Rectangle().fill(.red).frame(width: 10, height: 10).cornerRadius(2)
                        Text("fjernes").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 3) {
                        Rectangle().fill(.green).frame(width: 10, height: 10).cornerRadius(2)
                        Text("tilføjes").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            DiffTextView(attributed: diff)
                .frame(minHeight: 60, maxHeight: 260)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                .cornerRadius(8)

            HStack {
                Text("↩ indsæt · esc annullér")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Annullér", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Indsæt", action: onAccept)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 560)
        .background(.regularMaterial)
    }
}

/// Viser previewet som et flydende non-activating panel, så host-appen
/// beholder fokus og markering - dermed lander ⌘V det rigtige sted bagefter.
@MainActor
final class PreviewPanelController {
    private var panel: NSPanel?

    func show(title: String,
              original: String,
              corrected: String,
              onAccept: @escaping () -> Void,
              onCancel: @escaping () -> Void) {
        dismiss()

        let segments = DiffBuilder.diff(original: original, corrected: corrected)
        let attributed = DiffBuilder.attributedString(for: segments)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let view = PreviewView(
            title: title,
            diff: attributed,
            onAccept: { [weak self] in
                self?.dismiss()
                onAccept()
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )

        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)

        if let screen = NSScreen.main {
            let frame = panel.frame
            let x = screen.visibleFrame.midX - frame.width / 2
            let y = screen.visibleFrame.midY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}
