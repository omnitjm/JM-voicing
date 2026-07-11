import Foundation
import Combine
import Security

/// Brugerindstillinger. API-nøgler gemmes i Keychain (én pr. udbyder).
/// Udbydervalg, model og genveje i UserDefaults.
final class SettingsStore: ObservableObject {
    private let keychainService = "com.omnit.omnitgram"
    private let defaults = UserDefaults.standard

    // MARK: LLM-udbyder

    @Published var provider: LLMProvider {
        didSet {
            defaults.set(provider.rawValue, forKey: Keys.provider)
            // Skift til den gemte nøgle/model for den nye udbyder.
            apiKey = Self.loadKeychain(service: keychainService, account: provider.rawValue) ?? ""
            model = defaults.string(forKey: Keys.modelPrefix + provider.rawValue) ?? provider.defaultModel
        }
    }

    /// Nøglen for den AKTUELT valgte udbyder. Gemmes pr. udbyder i Keychain,
    /// så man kan skifte frem og tilbage uden at miste noget.
    @Published var apiKey: String {
        didSet { saveKeychain(account: provider.rawValue, value: apiKey) }
    }

    /// Modelnavn for den aktuelt valgte udbyder.
    @Published var model: String {
        didSet {
            let trimmed = model.trimmingCharacters(in: .whitespaces)
            defaults.set(trimmed.isEmpty ? provider.defaultModel : trimmed,
                         forKey: Keys.modelPrefix + provider.rawValue)
        }
    }

    // MARK: Preview

    /// Vis diff-preview og kræv accept før teksten erstattes.
    @Published var showPreview: Bool {
        didSet { defaults.set(showPreview, forKey: Keys.showPreview) }
    }

    // MARK: Genveje

    /// nil = genvejen er slået fra.
    @Published var grammarShortcut: ShortcutSpec? {
        didSet { saveShortcut(grammarShortcut, key: Keys.grammarShortcut) }
    }

    @Published var improveShortcut: ShortcutSpec? {
        didSet { saveShortcut(improveShortcut, key: Keys.improveShortcut) }
    }

    // MARK: Init

    init() {
        let provRaw = defaults.string(forKey: Keys.provider) ?? LLMProvider.anthropic.rawValue
        let prov = LLMProvider(rawValue: provRaw) ?? .anthropic
        self.provider = prov
        self.apiKey = Self.loadKeychain(service: "com.omnit.omnitgram", account: prov.rawValue) ?? ""
        self.model = defaults.string(forKey: Keys.modelPrefix + prov.rawValue) ?? prov.defaultModel

        self.showPreview = defaults.object(forKey: Keys.showPreview) as? Bool ?? true

        self.grammarShortcut = Self.loadShortcut(key: Keys.grammarShortcut,
                                                 fallback: .defaultGrammar,
                                                 defaults: defaults)
        self.improveShortcut = Self.loadShortcut(key: Keys.improveShortcut,
                                                 fallback: .defaultImprove,
                                                 defaults: defaults)
    }

    func resetShortcuts() {
        grammarShortcut = .defaultGrammar
        improveShortcut = .defaultImprove
    }

    func resetModel() {
        model = provider.defaultModel
    }

    /// Klar-til-brug service med de aktuelle indstillinger.
    func makeService() -> LLMService {
        LLMService(provider: provider, apiKey: apiKey, model: model)
    }

    // MARK: - UserDefaults keys

    private enum Keys {
        static let provider        = "llmProvider"
        static let modelPrefix     = "llmModel_"
        static let showPreview     = "showPreview"
        static let grammarShortcut = "grammarShortcut"
        static let improveShortcut = "improveShortcut"
        static let disabledMarker  = "__disabled__"
    }

    // MARK: - Shortcut persistence

    private func saveShortcut(_ shortcut: ShortcutSpec?, key: String) {
        if let shortcut = shortcut {
            if let data = try? JSONEncoder().encode(shortcut) {
                defaults.set(data, forKey: key)
            }
        } else {
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
