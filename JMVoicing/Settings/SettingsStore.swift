import Foundation
import Combine
import Security

/// Brugerindstillinger. API key gemmes i Keychain, alt andet i UserDefaults.
final class SettingsStore: ObservableObject {
    private let keychainService = "com.jm.voicing"
    private let keychainAccount = "openai_api_key"
    private let defaults = UserDefaults.standard

    @Published var apiKey: String {
        didSet { saveApiKey(apiKey) }
    }

    @Published var enableGrammarPolish: Bool {
        didSet { defaults.set(enableGrammarPolish, forKey: "enableGrammarPolish") }
    }

    init() {
        self.apiKey = Self.loadApiKeyStatic(service: "com.jm.voicing", account: "openai_api_key") ?? ""
        self.enableGrammarPolish = defaults.object(forKey: "enableGrammarPolish") as? Bool ?? true
    }

    // MARK: - Keychain

    private func saveApiKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(baseQuery as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var add = baseQuery
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func loadApiKeyStatic(service: String, account: String) -> String? {
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
