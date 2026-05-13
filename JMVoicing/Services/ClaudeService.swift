import Foundation

/// Sender transcriberet tekst til Anthropic's Messages API for grammatik-rettelse + tone-tilpasning.
/// Bruger Claude Opus 4.7 - bedst til dansk og tone-tilpasning.
///
/// Anthropic har ikke en officiel Swift SDK, så vi rammer REST-endpointet direkte via URLSession.
struct ClaudeService {
    let apiKey: String
    var model: String = "claude-opus-4-7"

    enum ClaudeError: Error, LocalizedError {
        case missingApiKey
        case http(Int, String)
        case decode

        var errorDescription: String? {
            switch self {
            case .missingApiKey:
                return "Manglende Anthropic API key. Åbn Indstillinger og tilføj den."
            case .http(let code, let body):
                return "Anthropic fejl (\(code)): \(body)"
            case .decode:
                return "Kunne ikke afkode svar fra Anthropic."
            }
        }
    }

    func polish(text: String, language: String) async throws -> String {
        guard !apiKey.isEmpty else { throw ClaudeError.missingApiKey }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // System prompt sendes som blok-array med cache_control så Anthropic cacher
        // det på tværs af gentagne dictations (samme sprog → samme system prompt).
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "output_config": ["effort": "max"],
            "system": [
                [
                    "type": "text",
                    "text": TonePrompt.systemPrompt(detectedLanguage: language),
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                ["role": "user", "content": trimmed]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.decode }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(no body)"
            throw ClaudeError.http(http.statusCode, bodyStr)
        }

        struct ClaudeResponse: Decodable {
            struct Block: Decodable {
                let type: String
                let text: String?
            }
            let content: [Block]
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            let firstText = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
            let cleaned = firstText.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? trimmed : cleaned
        } catch {
            throw ClaudeError.decode
        }
    }
}
