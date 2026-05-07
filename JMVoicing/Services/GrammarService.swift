import Foundation

/// Sender transcriberet tekst til OpenAI's chat completions API for grammatik-rettelse + tone-tilpasning.
/// Bruger gpt-4o-mini fordi det er hurtigt og billigt og fuldt nok til denne opgave.
struct GrammarService {
    let apiKey: String
    var model: String = "gpt-4o-mini"

    enum GrammarError: Error, LocalizedError {
        case missingApiKey
        case http(Int, String)
        case decode

        var errorDescription: String? {
            switch self {
            case .missingApiKey: return "Manglende OpenAI API key."
            case .http(let code, let body): return "OpenAI fejl (\(code)): \(body)"
            case .decode: return "Kunne ikke afkode svar fra OpenAI."
            }
        }
    }

    func polish(text: String, language: String) async throws -> String {
        guard !apiKey.isEmpty else { throw GrammarError.missingApiKey }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": TonePrompt.systemPrompt(detectedLanguage: language)],
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

        struct ChatResponse: Decodable {
            struct Choice: Decodable { let message: Message }
            struct Message: Decodable { let content: String }
            let choices: [Choice]
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            let cleaned = decoded.choices.first?.message.content
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed
            return cleaned
        } catch {
            throw GrammarError.decode
        }
    }
}
