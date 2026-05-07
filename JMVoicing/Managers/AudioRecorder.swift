import AVFoundation
import Foundation

/// Optager mikrofon-input til en midlertidig .m4a fil.
/// Whisper API understøtter m4a/aac så vi sparer båndbredde sammenlignet med wav.
final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?
    private(set) var currentURL: URL?

    enum RecorderError: Error {
        case permissionDenied
        case setupFailed(String)
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                cont.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { ok in cont.resume(returning: ok) }
            default:
                cont.resume(returning: false)
            }
        }
    }

    func start() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("jmvoicing-\(UUID().uuidString).m4a")
        currentURL = tmp

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let r = try AVAudioRecorder(url: tmp, settings: settings)
            r.isMeteringEnabled = false
            guard r.prepareToRecord() else {
                throw RecorderError.setupFailed("prepareToRecord fejlede")
            }
            guard r.record() else {
                throw RecorderError.setupFailed("record() fejlede - tjek mikrofontilladelse")
            }
            self.recorder = r
        } catch {
            throw RecorderError.setupFailed(error.localizedDescription)
        }
    }

    /// Stopper optagelse og returnerer URL'en til filen. Returnerer nil hvis ingen aktiv optagelse.
    func stop() -> URL? {
        guard let r = recorder else { return nil }
        r.stop()
        let url = currentURL
        recorder = nil
        return url
    }

    func cleanup(url: URL?) {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
