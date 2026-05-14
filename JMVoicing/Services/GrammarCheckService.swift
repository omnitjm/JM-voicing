import Foundation
import NaturalLanguage

/// Streng grammatik-rettelse uden at ændre tone, stil eller ordvalg.
/// Modsat ClaudeService.polish som tilpasser teksten til brugerens skrivestil,
/// laver denne kun det allermest nødvendige - som Grammarly.
struct GrammarCheckService {
    let apiKey: String
    var model: String = "claude-opus-4-7"

    enum GrammarError: Error, LocalizedError {
        case missingApiKey
        case http(Int, String)
        case decode
        case empty

        var errorDescription: String? {
            switch self {
            case .missingApiKey: return "Manglende Anthropic API key. Åbn Indstillinger."
            case .http(let code, let body): return "Anthropic fejl (\(code)): \(body)"
            case .decode: return "Kunne ikke afkode svar fra Anthropic."
            case .empty: return "Ingen tekst markeret."
            }
        }
    }

    /// Returnerer den rettede tekst. Hvis intet skal rettes returneres input uændret.
    func check(text: String) async throws -> String {
        guard !apiKey.isEmpty else { throw GrammarError.missingApiKey }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GrammarError.empty }

        let language = detectLanguage(text: trimmed)

        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "output_config": ["effort": "max"],
            "thinking": ["type": "adaptive"],
            "system": [
                [
                    "type": "text",
                    "text": Self.systemPrompt(language: language),
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                ["role": "user", "content": trimmed]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GrammarError.decode }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(no body)"
            throw GrammarError.http(http.statusCode, bodyStr)
        }

        struct ClaudeResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            let result = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
            let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? trimmed : cleaned
        } catch {
            throw GrammarError.decode
        }
    }

    // MARK: - Helpers

    private func detectLanguage(text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let code = recognizer.dominantLanguage?.rawValue ?? "en"
        return code == "da" ? "Danish" : "English"
    }

    private static func systemPrompt(language: String) -> String {
        """
        You are a strict grammar and spelling checker. The text below is in \(language).

        Your ONLY job is to correct:
        - Spelling mistakes
        - Grammar errors (verb tense, subject-verb agreement, articles, prepositions)
        - Punctuation
        - Obvious typos

        ABSOLUTE RULES:
        1. DO NOT rephrase, restructure, or rewrite sentences.
        2. DO NOT change the writer's tone, style, register, or word choice.
        3. DO NOT translate. If the input is Danish, keep it Danish. If English, keep it English.
        4. DO NOT add, remove, or summarize content.
        5. DO NOT change formal language to casual or vice versa.
        6. DO NOT change British to American English or vice versa.
        7. If a word is unusual but spelled correctly, leave it alone.
        8. If the text is already correct, return it EXACTLY as-is, byte for byte.
        9. Preserve all line breaks, paragraphs, and whitespace exactly as in the input.

        Output ONLY the corrected text. No preamble, no explanation, no markdown, no quotes around the result.
        """
    }
}
