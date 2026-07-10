import SwiftUI
import AppKit

@main
struct OmnitGramApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settingsStore)
        }
    }
}
