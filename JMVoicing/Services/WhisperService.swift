import Foundation

/// Sender en lydfil til OpenAI's transcription API (whisper-1) og returnerer transcription + sprogkode.
/// Auto-detekterer sprog når vi ikke specificerer "language".
struct WhisperService {
    let apiKey: String

    struct Result {
        let text: String
        let language: String  // ISO-639-1, fx "da" eller "en"
    }

    enum WhisperError: Error, LocalizedError {
        case missingApiKey
        case http(Int, String)
        case decode

        var errorDescription: String? {
            switch self {
            case .missingApiKey: return "Manglende OpenAI API key. Åbn Indstillinger og tilføj den."
            case .http(let code, let body): return "OpenAI fejl (\(code)): \(body)"
            case .decode: return "Kunne ikke afkode svar fra OpenAI."
            }
        }
    }

    func transcribe(fileURL: URL) async throws -> Result {
        guard !apiKey.isEmpty else { throw WhisperError.missingApiKey }

        let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let boundary = "----jmvoicing-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("model", "whisper-1")
        appendField("response_format", "verbose_json")
        // Hint som hjælper Whisper med at vælge mellem dansk/engelsk - men tvinger ikke et bestemt sprog.
        appendField("prompt", "Mixed Danish and English speech.")

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WhisperError.decode }
        guard (200..<300).contains(http.statusCode) else {
            let bodyStr = String(data: data, encoding: .utf8) ?? "(no body)"
            throw WhisperError.http(http.statusCode, bodyStr)
        }

        struct VerboseResponse: Decodable {
            let text: String
            let language: String?
        }
        do {
            let decoded = try JSONDecoder().decode(VerboseResponse.self, from: data)
            return Result(text: decoded.text, language: decoded.language ?? "en")
        } catch {
            throw WhisperError.decode
        }
    }
}
