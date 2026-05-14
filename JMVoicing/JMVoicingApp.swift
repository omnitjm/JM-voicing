import SwiftUI
import AppKit

@main
struct JMVoicingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // SwiftUI App requires at least one Scene. The real Settings UI is
    // presented via AppDelegate's own NSWindow (more reliable on Sequoia
    // for LSUIElement apps). This Settings scene only acts as a redirect
    // in case cmd+, or showSettingsWindow: ever reaches it.
    var body: some Scene {
        Settings {
            SettingsRedirect(appDelegate: appDelegate)
        }
    }
}

private struct SettingsRedirect: View {
    let appDelegate: AppDelegate

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                DispatchQueue.main.async {
                    NSApp.keyWindow?.close()
                    appDelegate.openSettingsFromExternal()
                }
            }
    }
}
