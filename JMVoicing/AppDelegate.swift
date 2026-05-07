import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var dictationCoordinator: DictationCoordinator!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(state: .idle)
        configureMenu()

        dictationCoordinator = DictationCoordinator(settingsStore: settingsStore)
        dictationCoordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateStatusIcon(state: state) }
            .store(in: &cancellables)

        hotkeyManager = HotkeyManager(
            onPress: { [weak self] in self?.dictationCoordinator.startRecording() },
            onRelease: { [weak self] in self?.dictationCoordinator.stopAndProcess() }
        )
        hotkeyManager.start()
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "JM Voicing", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Hold Fn for at diktere", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Indstillinger…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Afslut", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusIcon(state: DictationCoordinator.State) {
        guard let button = statusItem.button else { return }
        let symbolName: String
        switch state {
        case .idle:        symbolName = "mic"
        case .recording:   symbolName = "mic.fill"
        case .transcribing: symbolName = "waveform"
        case .processing:  symbolName = "sparkles"
        case .error:       symbolName = "exclamationmark.triangle"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "JM Voicing")
        button.image?.isTemplate = true
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
