import Foundation

/// Eksekverer en PresetCommand mod Anthropic Messages API.
/// Samme struktur som InlineCommandService men med preset's system prompt
/// og uden brugerens kommando-tekst - kun den markerede tekst som input.
struct PresetCommandService {
    let apiKey: String
    var model: String = "claude-opus-4-7"

    enum PresetError: Error, LocalizedError {
        case missingApiKey
        case emptyInput
        case http(Int, String)
        case decode

        var errorDescription: String? {
            switch self {
            case .missingApiKey: return "Manglende Anthropic API key. Åbn Indstillinger."
            case .emptyInput:    return "Ingen tekst markeret."
            case .http(let code, let body): return "Anthropic fejl (\(code)): \(body)"
            case .decode:        return "Kunne ikke afkode svar fra Anthropic."
            }
        }
    }

    func run(preset: PresetCommand, text: String) async throws -> String {
        guard !apiKey.isEmpty else { throw PresetError.missingApiKey }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PresetError.emptyInput }

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
                    "text": preset.systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                ["role": "user", "content": trimmed]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PresetError.decode }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(no body)"
            throw PresetError.http(http.statusCode, bodyStr)
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
            throw PresetError.decode
        }
    }
}
