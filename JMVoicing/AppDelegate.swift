import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var dictationCoordinator: DictationCoordinator!
    private var selectionCoordinator: SelectionActionCoordinator!
    private var grammarHotkey: GlobalHotkey?
    private var commandHotkey: GlobalHotkey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(state: .idle)
        configureMenu()

        selectionCoordinator = SelectionActionCoordinator(settingsStore: settingsStore)

        dictationCoordinator = DictationCoordinator(settingsStore: settingsStore)
        dictationCoordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateStatusIcon(state: state) }
            .store(in: &cancellables)

        // Fn / Globus - push-to-talk dictation
        hotkeyManager = HotkeyManager(
            onPress: { [weak self] in self?.dictationCoordinator.startRecording() },
            onRelease: { [weak self] in self?.dictationCoordinator.stopAndProcess() }
        )
        hotkeyManager.start()

        // ⌃⌥G - grammar check på markeret tekst
        grammarHotkey = GlobalHotkey(keyCode: .g, modifiers: [.control, .option]) { [weak self] in
            self?.selectionCoordinator.runGrammarCheck()
        }

        // ⌃⌥A - AI command palette
        commandHotkey = GlobalHotkey(keyCode: .a, modifiers: [.control, .option]) { [weak self] in
            self?.selectionCoordinator.runInlineCommand()
        }
    }

    private func configureMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "JM Voicing", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(NSMenuItem.separator())

        addShortcutItem(menu, title: "Hold Fn", subtitle: "diktér og indsæt ved markøren")
        addShortcutItem(menu, title: "⌃⌥G", subtitle: "tjek grammatik på markeret tekst")
        addShortcutItem(menu, title: "⌃⌥A", subtitle: "AI-kommando på markeret tekst")

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Indstillinger…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Afslut JM Voicing", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func addShortcutItem(_ menu: NSMenu, title: String, subtitle: String) {
        let attributed = NSMutableAttributedString(
            string: "\(title)   ",
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)]
        )
        attributed.append(NSAttributedString(
            string: subtitle,
            attributes: [.font: NSFont.systemFont(ofSize: 12),
                         .foregroundColor: NSColor.secondaryLabelColor]
        ))
        let item = NSMenuItem()
        item.attributedTitle = attributed
        item.isEnabled = false
        menu.addItem(item)
    }

    private func updateStatusIcon(state: DictationCoordinator.State) {
        guard let button = statusItem.button else { return }
        let symbolName: String
        switch state {
        case .idle:         symbolName = "mic"
        case .recording:    symbolName = "mic.fill"
        case .transcribing: symbolName = "waveform"
        case .processing:   symbolName = "sparkles"
        case .error:        symbolName = "exclamationmark.triangle"
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
