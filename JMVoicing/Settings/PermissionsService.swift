import Foundation
import AppKit
import AVFoundation
import Speech
import ApplicationServices

/// Forespørger + åbner System Settings-paneler for de tre tilladelser app'en bruger.
enum PermissionStatus {
    case granted
    case denied
    case notDetermined

    var label: String {
        switch self {
        case .granted: return "Givet"
        case .denied: return "Afvist"
        case .notDetermined: return "Ikke spurgt endnu"
        }
    }

    var symbol: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle"
        }
    }
}

enum PermissionsService {

    // MARK: - Status

    static func microphoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func speechStatus() -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    static func accessibilityStatus() -> PermissionStatus {
        AXIsProcessTrusted() ? .granted : .denied
    }

    // MARK: - Request prompts

    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { ok in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func requestSpeech(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { completion(status == .authorized) }
        }
    }

    /// Trigger Accessibility-prompten ved at kalde AXIsProcessTrustedWithOptions
    /// med prompt-flag. Hvis brugeren afviser eller har afvist tidligere, åbner
    /// vi System Settings i stedet.
    @discardableResult
    static func requestAccessibility() -> Bool {
        let opts: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        return AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: - Åbn System Settings-paneler direkte

    static func openMicrophoneSettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    static func openSpeechSettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
    }

    static func openAccessibilitySettings() {
        openURL("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openKeyboardSettings() {
        openURL("x-apple.systempreferences:com.apple.preference.keyboard")
    }

    private static func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
