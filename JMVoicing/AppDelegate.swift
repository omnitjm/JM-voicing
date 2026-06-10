import AppKit
import AVFoundation
import Speech
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
    private var improveHotkey: GlobalHotkey?
    private var welcomeWindow: WelcomeWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

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
        registerImproveHotkey()
        observeSettings()

        welcomeWindow = WelcomeWindowController(settingsStore: settingsStore)
        let firstLaunch = !settingsStore.hasSeenWelcome
        if firstLaunch {
            settingsStore.hasSeenWelcome = true
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                self?.welcomeWindow?.show()
            }
        } else {
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.warnAboutMissingSetup()
            }
        }
    }

    @objc private func showWelcome() {
        Task { @MainActor [weak self] in
            self?.welcomeWindow?.show()
        }
    }

    // MARK: - Setup-tjek
    //
    // På Sequoia er det meget svært at debugge "intet sker når jeg trykker Fn".
    // Vi tjekker derfor de mest typiske setup-fejl ved start og fortæller
    // brugeren hvad der mangler. Vises kun hvis noget faktisk mangler.
    private func warnAboutMissingSetup() {
        var problems: [String] = []

        if !AXIsProcessTrusted() {
            problems.append("• Accessibility er ikke tilladt. Uden den virker hverken Fn-diktering, ⌃⌥G eller ⌃⌥A.")
        }

        if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
            problems.append("• Mikrofon-adgang er afvist. Diktering kan ikke optage lyd.")
        }

        if SFSpeechRecognizer.authorizationStatus() == .denied {
            problems.append("• Speech Recognition er afvist. Diktering kan ikke omdanne tale til tekst.")
        }

        if settingsStore.anthropicApiKey.isEmpty {
            problems.append("• Anthropic API key mangler. Åbn Indstillinger og indsæt din key.")
        }

        guard !problems.isEmpty else { return }

        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        let alert = NSAlert()
        alert.messageText = "Gramchek er ikke helt klar endnu"
        alert.informativeText = problems.joined(separator: "\n\n")
            + "\n\nÅbn System Settings → Privacy & Security for at give tilladelser, og åbn Indstillinger her i appen for API key. Genstart appen efter du har givet tilladelser."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Åbn Privacy & Security")
        alert.addButton(withTitle: "Åbn Indstillinger")
        alert.addButton(withTitle: "Senere")
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
                NSWorkspace.shared.open(url)
            }
        case .alertSecondButtonReturn:
            openSettings()
        default:
            break
        }
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

    private func registerImproveHotkey() {
        improveHotkey = nil
        guard let spec = settingsStore.improveShortcut else { return }
        improveHotkey = GlobalHotkey(spec: spec) { [weak self] in
            self?.selectionCoordinator.runImprove()
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

        let title = NSMenuItem(title: "Gramchek", action: nil, keyEquivalent: "")
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

        if let i = settingsStore.improveShortcut {
            addShortcutItem(menu, keys: i.display, subtitle: "forbedr markeret tekst (samme mening)")
        } else {
            addShortcutItem(menu, keys: "—", subtitle: "improve (slået fra)")
        }

        if let c = settingsStore.commandShortcut {
            addShortcutItem(menu, keys: c.display, subtitle: "AI-kommando på markeret tekst")
        } else {
            addShortcutItem(menu, keys: "—", subtitle: "AI-kommando (slået fra)")
        }

        menu.addItem(NSMenuItem.separator())
        let demoItem = NSMenuItem(title: "Vis demo / velkomst", action: #selector(showWelcome), keyEquivalent: "")
        demoItem.target = self
        menu.addItem(demoItem)

        let settingsItem = NSMenuItem(title: "Indstillinger…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Afslut Gramchek", action: #selector(quit), keyEquivalent: "q")
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
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Gramchek")
        button.image?.isTemplate = true
    }

    /// Public entry point used by the SwiftUI `Settings` scene fallback. Same
    /// behavior as the menu's `openSettings` action.
    func openSettingsFromExternal() {
        openSettings()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Gramchek — Indstillinger"
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("JMVoicingSettings")
            let view = SettingsView().environmentObject(settingsStore)
            window.contentView = NSHostingView(rootView: view)
            settingsWindow = window
        }
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
