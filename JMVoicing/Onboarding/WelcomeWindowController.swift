import AppKit
import SwiftUI

/// NSWindow-wrapper omkring WelcomeView. Vises på første launch og kan
/// genåbnes via menu baren. Skal kun bruges fra main thread.
@MainActor
final class WelcomeWindowController {
    private var window: NSWindow?
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func show() {
        if let existing = window {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        let view = WelcomeView(onDismiss: { [weak self] in self?.dismiss() })
            .environmentObject(settingsStore)

        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "JM Voicing - velkommen"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .normal
        window.collectionBehavior = [.fullScreenAuxiliary]

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func dismiss() {
        window?.orderOut(nil)
        window = nil
    }
}
