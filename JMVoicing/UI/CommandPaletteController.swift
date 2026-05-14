import AppKit
import SwiftUI

/// Viser CommandPaletteView som et flydende non-activating panel oven på alle apps.
/// Vi bruger NSPanel + .nonactivatingPanel så panelet kan modtage tastatur-input
/// uden at JM Voicing bliver "frontmost" - så ⌘V efter eksekvering rammer den
/// app brugeren oprindeligt arbejdede i.
@MainActor
final class CommandPaletteController {
    private var panel: NSPanel?

    func show(selectedText: String?,
              onSubmit: @escaping (String) -> Void,
              onPreset: @escaping (PresetCommand) -> Void,
              onCancel: @escaping () -> Void) {
        if let existing = panel {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
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

        let view = CommandPaletteView(
            selectedText: selectedText,
            onSubmit: { [weak self] command in
                self?.dismiss()
                onSubmit(command)
            },
            onPreset: { [weak self] preset in
                self?.dismiss()
                onPreset(preset)
            },
            onCancel: { [weak self] in
                self?.dismiss()
                onCancel()
            }
        )

        let hosting = NSHostingView(rootView: view)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)

        if let screen = NSScreen.main {
            let frame = panel.frame
            let x = screen.frame.midX - frame.width / 2
            let y = screen.frame.midY + 100
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
