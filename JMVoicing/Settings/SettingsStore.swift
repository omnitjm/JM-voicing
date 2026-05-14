import Foundation
import Combine
import Security

/// Brugerindstillinger. API key gemmes i Keychain. Genveje og prefs i UserDefaults.
final class SettingsStore: ObservableObject {
    private let keychainService = "com.jm.voicing"
    private let anthropicAccount = "anthropic_api_key"
    private let defaults = UserDefaults.standard

    // MARK: Keychain - API key

    @Published var anthropicApiKey: String {
        didSet { saveKeychain(account: anthropicAccount, value: anthropicApiKey) }
    }

    // MARK: Toggles

    @Published var enableGrammarPolish: Bool {
        didSet { defaults.set(enableGrammarPolish, forKey: Keys.enableGrammarPolish) }
    }

    @Published var hasSeenWelcome: Bool {
        didSet { defaults.set(hasSeenWelcome, forKey: Keys.hasSeenWelcome) }
    }

    // MARK: Genveje

    @Published var dictationTrigger: DictationTrigger {
        didSet {
            defaults.set(dictationTrigger.rawValue, forKey: Keys.dictationTrigger)
        }
    }

    /// nil = ingen genvej for grammar-tjek (slået fra).
    @Published var grammarShortcut: ShortcutSpec? {
        didSet { saveShortcut(grammarShortcut, key: Keys.grammarShortcut) }
    }

    /// nil = ingen genvej for AI-kommando palette (slået fra).
    @Published var commandShortcut: ShortcutSpec? {
        didSet { saveShortcut(commandShortcut, key: Keys.commandShortcut) }
    }

    // MARK: Init

    init() {
        self.anthropicApiKey = Self.loadKeychain(service: "com.jm.voicing", account: "anthropic_api_key") ?? ""
        self.enableGrammarPolish = defaults.object(forKey: Keys.enableGrammarPolish) as? Bool ?? true
        self.hasSeenWelcome = defaults.bool(forKey: Keys.hasSeenWelcome)

        let trigRaw = defaults.string(forKey: Keys.dictationTrigger) ?? DictationTrigger.fn.rawValue
        self.dictationTrigger = DictationTrigger(rawValue: trigRaw) ?? .fn

        self.grammarShortcut = Self.loadShortcut(key: Keys.grammarShortcut,
                                                 fallback: .defaultGrammar,
                                                 defaults: defaults)
        self.commandShortcut = Self.loadShortcut(key: Keys.commandShortcut,
                                                 fallback: .defaultCommand,
                                                 defaults: defaults)
    }

    // MARK: Reset til defaults

    func resetGrammarShortcut() { grammarShortcut = .defaultGrammar }
    func resetCommandShortcut() { commandShortcut = .defaultCommand }
    func resetDictationTrigger() { dictationTrigger = .fn }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let enableGrammarPolish = "enableGrammarPolish"
        static let dictationTrigger    = "dictationTrigger"
        static let grammarShortcut     = "grammarShortcut"
        static let commandShortcut     = "commandShortcut"
        static let hasSeenWelcome      = "hasSeenWelcome"
        // Sentinel-værdi når en nullable shortcut bevidst er fjernet af brugeren.
        static let disabledMarker      = "__disabled__"
    }

    // MARK: - Shortcut persistence

    private func saveShortcut(_ shortcut: ShortcutSpec?, key: String) {
        if let shortcut = shortcut {
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: key)
            }
        } else {
            // Markér eksplicit som "fra" så vi ikke loader default ved næste start.
            defaults.set(Keys.disabledMarker, forKey: key)
        }
    }

    private static func loadShortcut(key: String,
                                     fallback: ShortcutSpec,
                                     defaults: UserDefaults) -> ShortcutSpec? {
        if let str = defaults.string(forKey: key), str == Keys.disabledMarker {
            return nil
        }
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ShortcutSpec.self, from: data) {
            return decoded
        }
        return fallback
    }

    // MARK: - Keychain

    private func saveKeychain(account: String, value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var add = baseQuery
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func loadKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}
