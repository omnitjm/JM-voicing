import SwiftUI
import AppKit

@main
struct JMVoicingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settingsStore)
        }
    }
}
