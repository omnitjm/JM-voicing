import AppKit
import SwiftUI
import Combine
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settingsStore = SettingsStore()
    private var statusItem: NSStatusItem!
    private var coordinator: SelectionActionCoordinator!
    private var grammarHotkey: GlobalHotkey?
    private var improveHotkey: GlobalHotkey?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        coordinator = SelectionActionCoordinator(settingsStore: settingsStore)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(state: .idle)
        refreshMenu()

        coordinator.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateStatusIcon(state: state) }
            .store(in: &cancellables)

        // Bed om Accessibility-tilladelse ved første start (kræves for at
        // læse markeret tekst og indsætte resultatet).
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(opts)

        registerGrammarHotkey()
        registerImproveHotkey()
        observeSettings()
    }

    // MARK: - Hotkeys

    private func observeSettings() {
        settingsStore.$grammarShortcut
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerGrammarHotkey()
                self?.refreshMenu()
            }
            .store(in: &cancellables)

        settingsStore.$improveShortcut
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerImproveHotkey()
                self?.refreshMenu()
            }
            .store(in: &cancellables)
    }

    private func registerGrammarHotkey() {
        grammarHotkey = nil  // unregistrér via deinit
        guard let spec = settingsStore.grammarShortcut else { return }
        grammarHotkey = GlobalHotkey(spec: spec) { [weak self] in
            self?.coordinator.runGrammarFix()
        }
    }

    private func registerImproveHotkey() {
        improveHotkey = nil
        guard let spec = settingsStore.improveShortcut else { return }
        improveHotkey = GlobalHotkey(spec: spec) { [weak self] in
            self?.coordinator.runImprove()
        }
    }

    // MARK: - Menu bar

    private func refreshMenu() {
        let menu = NSMenu()

        let title = NSMenuItem(title: "OmnitGram", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(NSMenuItem.separator())

        // Klikbare menu-punkter så man også kan køre uden genvej.
        let fixItem = NSMenuItem(title: "Ret grammatik på markeret tekst", action: #selector(runGrammarFromMenu), keyEquivalent: "")
        fixItem.target = self
        fixItem.image = NSImage(systemSymbolName: "checkmark.seal", accessibilityDescription: nil)
        menu.addItem(fixItem)

        let improveItem = NSMenuItem(title: "Optimér sproget på markeret tekst", action: #selector(runImproveFromMenu), keyEquivalent: "")
        improveItem.target = self
        improveItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
        menu.addItem(improveItem)

        menu.addItem(NSMenuItem.separator())

        addShortcutHint(menu,
                        keys: settingsStore.grammarShortcut?.display ?? "—",
                        subtitle: "ret grammatik")
        addShortcutHint(menu,
                        keys: settingsStore.improveShortcut?.display ?? "—",
                        subtitle: "optimér sproget")

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(title: "Indstillinger…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Afslut OmnitGram", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func addShortcutHint(_ menu: NSMenu, keys: String, subtitle: String) {
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

    private func updateStatusIcon(state: SelectionActionCoordinator.State) {
        guard let button = statusItem.button else { return }
        let symbolName: String
        switch state {
        case .idle:    symbolName = "checkmark.seal"
        case .working: symbolName = "hourglass"
        case .error:   symbolName = "exclamationmark.triangle"
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "OmnitGram")
        button.image?.isTemplate = true
    }

    // MARK: - Actions

    @objc private func runGrammarFromMenu() {
        coordinator.runGrammarFix()
    }

    @objc private func runImproveFromMenu() {
        coordinator.runImprove()
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
