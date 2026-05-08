import Foundation
import Speech
import NaturalLanguage

/// Transcriberer en lydfil med macOS' indbyggede SFSpeechRecognizer.
///
/// Vi kender ikke sproget på forhånd, så vi kører dansk og engelsk parallelt
/// og vælger det resultat med højest gennemsnitlig confidence.
/// On-device hvor muligt - så ingen lyd sendes til Apple, og det virker offline.
struct NativeSpeechService {

    struct Result {
        let text: String
        let language: String  // "da" eller "en"
    }

    enum SpeechError: Error, LocalizedError {
        case notAuthorized
        case noResult
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech Recognition er ikke tilladt. Tildel adgang i System Settings → Privacy & Security → Speech Recognition."
            case .noResult:
                return "Kunne ikke genkende tale. Prøv at tale lidt højere eller tættere på mikrofonen."
            case .recognizerUnavailable:
                return "Speech Recognition er midlertidigt utilgængelig."
            }
        }
    }

    /// Beder om tilladelse første gang. Kald før første transcription.
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    func transcribe(fileURL: URL) async throws -> Result {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw SpeechError.notAuthorized
        }

        async let danishTask = recognize(fileURL: fileURL, locale: Locale(identifier: "da-DK"))
        async let englishTask = recognize(fileURL: fileURL, locale: Locale(identifier: "en-US"))

        let danish = try? await danishTask
        let english = try? await englishTask

        // Vælg det resultat med højest confidence. Hvis kun én lykkedes, brug den.
        switch (danish, english) {
        case (nil, nil):
            throw SpeechError.noResult
        case (let da?, nil):
            return Result(text: da.text, language: "da")
        case (nil, let en?):
            return Result(text: en.text, language: "en")
        case (let da?, let en?):
            // Hvis confidence er tæt på (< 0.05 forskel), brug NLLanguageRecognizer
            // til at afgøre hvilket sprog der reelt blev talt.
            if abs(da.confidence - en.confidence) < 0.05 {
                let detected = detectLanguage(text: da.confidence > en.confidence ? da.text : en.text)
                if detected == "en" {
                    return Result(text: en.text, language: "en")
                }
                return Result(text: da.text, language: "da")
            }
            return da.confidence >= en.confidence
                ? Result(text: da.text, language: "da")
                : Result(text: en.text, language: "en")
        }
    }

    // MARK: - Helpers

    private struct Recognized {
        let text: String
        let confidence: Float
    }

    private func recognize(fileURL: URL, locale: Locale) async throws -> Recognized {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { cont in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let result = result, result.isFinal else { return }

                let segments = result.bestTranscription.segments
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let avgConfidence: Float = segments.isEmpty
                    ? 0
                    : segments.map(\.confidence).reduce(0, +) / Float(segments.count)
                cont.resume(returning: Recognized(text: text, confidence: avgConfidence))
            }
        }
    }

    private func detectLanguage(text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue ?? "da"
    }
}
