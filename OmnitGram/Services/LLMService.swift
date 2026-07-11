import Foundation
import NaturalLanguage

/// Hvilken LLM-udbyder brugeren har valgt i Settings.
enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic
    case openai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai:    return "OpenAI (GPT)"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-opus-4-7"
        case .openai:    return "gpt-4o"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-..."
        case .openai:    return "sk-..."
        }
    }

    var keyHelpURL: String {
        switch self {
        case .anthropic: return "console.anthropic.com"
        case .openai:    return "platform.openai.com/api-keys"
        }
    }
}

/// De to ting appen kan: ret grammatik eller optimér sproget.
enum TextAction {
    case fixGrammar
    case improveLanguage
}

/// Kalder den valgte LLM-udbyder med den markerede tekst og returnerer resultatet.
struct LLMService {
    let provider: LLMProvider
    let apiKey: String
    let model: String

    enum LLMError: Error, LocalizedError {
        case missingApiKey
        case http(Int, String)
        case decode
        case truncated

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "Manglende API-nøgle. Åbn Indstillinger og tilføj den."
            case .http(let code, let body):
                let hint: String
                switch code {
                case 401: hint = "API-nøglen er ugyldig. Tjek den i Indstillinger."
                case 429: hint = "Rate limit ramt - vent et øjeblik og prøv igen."
                case 402, 403: hint = "Tjek at der er penge på kontoen hos udbyderen."
                default: hint = ""
                }
                return "Fejl fra udbyderen (\(code)). \(hint)\n\(body.prefix(300))"
            case .decode:
                return "Kunne ikke læse svaret fra udbyderen."
            case .truncated:
                return "Teksten er for lang til at blive behandlet i ét hug. Markér en mindre del ad gangen - intet blev ændret."
            }
        }
    }

    /// Kør en action på teksten. Returnerer den behandlede tekst.
    func run(_ action: TextAction, on text: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw LLMError.missingApiKey
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let language = detectLanguage(text: trimmed)
        let system = Self.systemPrompt(action: action, language: language)

        let result: String
        switch provider {
        case .anthropic:
            result = try await callAnthropic(system: system, user: trimmed)
        case .openai:
            result = try await callOpenAI(system: system, user: trimmed)
        }

        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? trimmed : cleaned
    }

    // MARK: - Prompts

    private static func systemPrompt(action: TextAction, language: String) -> String {
        switch action {
        case .fixGrammar:
            return """
            You are a strict grammar and spelling checker. The text is in \(language).

            Correct ONLY:
            - Spelling mistakes
            - Grammar errors (verb tense, agreement, articles, prepositions)
            - Punctuation
            - Obvious typos

            ABSOLUTE RULES:
            1. DO NOT rephrase, restructure, or rewrite sentences.
            2. DO NOT change tone, style, register, or word choice.
            3. DO NOT translate. Danish stays Danish; English stays English.
            4. DO NOT add, remove, or summarize content.
            5. If a word is unusual but spelled correctly, leave it alone.
            6. If the text is already correct, return it EXACTLY as-is.
            7. Preserve all line breaks and whitespace exactly.

            Output ONLY the corrected text - no preamble, no explanation, no markdown, no quotes.
            """
        case .improveLanguage:
            return """
            You are a language improvement assistant. The text is in \(language).

            Improve the text so it reads clearly and naturally:
            - Fix all spelling, grammar, and punctuation errors
            - Smooth out awkward phrasing and improve flow
            - Tighten wordy sentences
            - Choose more precise words where the original is vague

            RULES:
            1. Keep the SAME language. Danish stays Danish; English stays English.
            2. Keep the writer's tone and register - formal stays formal, casual stays casual.
            3. Keep ALL meaning and content. Do not add new points or drop existing ones.
            4. Do not make it sound AI-generated - no filler phrases, keep it human.
            5. Preserve paragraph structure and line breaks where they carry meaning.

            Output ONLY the improved text - no preamble, no explanation, no markdown, no quotes.
            """
        }
    }

    private func detectLanguage(text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let code = recognizer.dominantLanguage?.rawValue ?? "en"
        switch code {
        case "da":             return "Danish"
        case "no", "nb", "nn": return "Norwegian"
        case "sv":             return "Swedish"
        case "de":             return "German"
        default:               return "English"
        }
    }

    // MARK: - Anthropic

    private func callAnthropic(system: String, user: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "system": [
                ["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]
            ],
            "messages": [
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.decode }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        struct AnthropicResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
            let stop_reason: String?
        }
        guard let decoded = try? JSONDecoder().decode(AnthropicResponse.self, from: data) else {
            throw LLMError.decode
        }
        // Afkortet svar må ALDRIG pastes - hellere fejle tydeligt.
        if decoded.stop_reason == "max_tokens" {
            throw LLMError.truncated
        }
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
    }

    // MARK: - OpenAI

    private func callOpenAI(system: String, user: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90

        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.decode }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                let message: Message
                let finish_reason: String?
            }
            struct Message: Decodable { let content: String }
            let choices: [Choice]
        }
        guard let decoded = try? JSONDecoder().decode(OpenAIResponse.self, from: data) else {
            throw LLMError.decode
        }
        // Afkortet svar må ALDRIG pastes - hellere fejle tydeligt.
        if decoded.choices.first?.finish_reason == "length" {
            throw LLMError.truncated
        }
        return decoded.choices.first?.message.content ?? ""
    }
}
