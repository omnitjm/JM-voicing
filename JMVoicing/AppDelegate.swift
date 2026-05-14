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

        // Fn / Globus - push-to-talk dictation. Brugeren kan ændre tasten i Settings.
        hotkeyManager = HotkeyManager(
            trigger: settingsStore.dictationTrigger,
            onPress: { [weak self] in self?.dictationCoordinator.startRecording() },
            onRelease: { [weak self] in self?.dictationCoordinator.stopAndProcess() }
        )
        hotkeyManager.start()

        registerGrammarHotkey()
        registerCommandHotkey()
        observeSettings()
    }

    // MARK: - Observere settings-ændringer og re-registrere genveje live

    private func observeSettings() {
        settingsStore.$dictationTrigger
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] new in
                self?.hotkeyManager.update(trigger: new)
                self?.refreshMenu()
            }
            .store(in: &cancellables)

        settingsStore.$grammarShortcut
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerGrammarHotkey()
                self?.refreshMenu()
            }
            .store(in: &cancellables)

        settingsStore.$commandShortcut
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerCommandHotkey()
                self?.refreshMenu()
            }
            .store(in: &cancellables)
    }

    private func registerGrammarHotkey() {
        grammarHotkey = nil  // unregistrér via deinit
        guard let spec = settingsStore.grammarShortcut else { return }
        grammarHotkey = GlobalHotkey(spec: spec) { [weak self] in
            self?.selectionCoordinator.runGrammarCheck()
        }
    }

    private func registerCommandHotkey() {
        commandHotkey = nil
        guard let spec = settingsStore.commandShortcut else { return }
        commandHotkey = GlobalHotkey(spec: spec) { [weak self] in
            self?.selectionCoordinator.runInlineCommand()
        }
    }

    // MARK: - Menu bar

    private func configureMenu() {
        statusItem.menu = buildMenu()
    }

    private func refreshMenu() {
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let title = NSMenuItem(title: "JM Voicing", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(NSMenuItem.separator())

        addShortcutItem(menu,
                        keys: "Hold \(settingsStore.dictationTrigger.display)",
                        subtitle: "diktér og indsæt ved markøren")

        if let g = settingsStore.grammarShortcut {
            addShortcutItem(menu, keys: g.display, subtitle: "tjek grammatik på markeret tekst")
        } else {
            addShortcutItem(menu, keys: "—", subtitle: "grammar-check (slået fra)")
        }

        if let c = settingsStore.commandShortcut {
            addShortcutItem(menu, keys: c.display, subtitle: "AI-kommando på markeret tekst")
        } else {
            addShortcutItem(menu, keys: "—", subtitle: "AI-kommando (slået fra)")
        }

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Indstillinger…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Afslut JM Voicing", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func addShortcutItem(_ menu: NSMenu, keys: String, subtitle: String) {
        let attributed = NSMutableAttributedString(
            string: "\(keys)   ",
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
        if #available(macOS 14, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        // LSUIElement=true apps on Sequoia sometimes fail to bring the Settings
        // window forward via the standard action alone. Force it ourselves.
        DispatchQueue.main.async {
            for window in NSApp.windows {
                let name = window.frameAutosaveName.lowercased()
                let title = window.title.lowercased()
                if name.contains("settings") || name.contains("preferences")
                    || title.contains("settings") || title.contains("indstillinger") {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    return
                }
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
