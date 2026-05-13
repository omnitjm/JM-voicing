import Foundation

/// Tag markeret tekst som kontekst + en bruger-skreven kommando, og lad Claude
/// returnere ny tekst der skal erstatte (eller blive indsat efter) det markerede.
///
/// Eksempel: marker en mail, tryk hotkey, skriv "svar høfligt nej med disse punkter: ..."
struct InlineCommandService {
    let apiKey: String
    var model: String = "claude-opus-4-7"

    enum InlineError: Error, LocalizedError {
        case missingApiKey
        case http(Int, String)
        case decode

        var errorDescription: String? {
            switch self {
            case .missingApiKey: return "Manglende Anthropic API key. Åbn Indstillinger."
            case .http(let code, let body): return "Anthropic fejl (\(code)): \(body)"
            case .decode: return "Kunne ikke afkode svar fra Anthropic."
            }
        }
    }

    /// `selectedText` kan være tom hvis brugeren bare vil skrive en fritstående kommando.
    func run(command: String, selectedText: String?) async throws -> String {
        guard !apiKey.isEmpty else { throw InlineError.missingApiKey }
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCommand.isEmpty else { return "" }

        var userParts: [String] = []
        if let sel = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines), !sel.isEmpty {
            userParts.append("Selected text:\n<<<\n\(sel)\n>>>\n")
        }
        userParts.append("Command: \(trimmedCommand)")
        let userMessage = userParts.joined(separator: "\n")

        let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "output_config": ["effort": "max"],
            "thinking": ["type": "adaptive"],
            "system": [
                [
                    "type": "text",
                    "text": Self.systemPrompt,
                    "cache_control": ["type": "ephemeral"]
                ]
            ],
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw InlineError.decode }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(no body)"
            throw InlineError.http(http.statusCode, bodyStr)
        }

        struct ClaudeResponse: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }

        do {
            let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
            let result = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw InlineError.decode
        }
    }

    private static let systemPrompt = """
    You are an inline writing assistant invoked from a global hotkey on macOS.

    The user has (optionally) selected some text in any app, and given you a command.
    Your output will be pasted directly back into that app, replacing the selection
    if there was one, or inserted at the cursor otherwise.

    Rules:
    - Output ONLY the text that should be pasted. No preamble like "Here is..." or
      "Sure, here's...". No markdown fences. No explanations.
    - Match the language of the selected text. If no selection, match the language
      of the command itself. Danish stays Danish; English stays English.
    - Match the register of the selected text - formal stays formal, casual stays casual.
    - If the command is an answer/reply (e.g. "answer this with these points"),
      write the answer directly - do NOT include the original message above it.
    - If the command is a rewrite (e.g. "make this shorter"), return only the rewritten
      version - not the original.
    - Use the user's tone: natural, direct, no AI-flavoured filler ("derudover",
      "endvidere", "I hope this helps").
    - If the command is ambiguous, make a reasonable choice and proceed - do NOT ask
      clarifying questions in your output.
    """
}
