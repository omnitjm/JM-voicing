import Foundation
import Carbon.HIToolbox
import AppKit

/// Registrér globale tastatur-genveje via Carbon's RegisterEventHotKey.
/// I modsætning til CGEventTap (som vi bruger til Fn) "stjæler" disse genveje
/// tastetrykket fra andre apps, så ⌃⌥G fx ikke når frem til Slack når vores
/// genvej rammer.
final class GlobalHotkey {

    /// macOS virtuelle key codes vi har brug for. Se Carbon/HIToolbox/Events.h.
    enum KeyCode: UInt32 {
        case g = 5
        case a = 0
        case space = 49
        case k = 40
        case f = 3
    }

    /// Carbon modifier flags - kombinér med OR.
    struct Modifiers: OptionSet {
        let rawValue: UInt32
        static let command = Modifiers(rawValue: UInt32(cmdKey))
        static let shift   = Modifiers(rawValue: UInt32(shiftKey))
        static let option  = Modifiers(rawValue: UInt32(optionKey))
        static let control = Modifiers(rawValue: UInt32(controlKey))
    }

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextId: UInt32 = 1
    private static var carbonHandlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    init(keyCode: KeyCode, modifiers: Modifiers, handler: @escaping () -> Void) {
        id = Self.nextId
        Self.nextId += 1
        Self.handlers[id] = handler
        Self.installCarbonHandlerIfNeeded()

        var hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var hkRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode.rawValue, modifiers.rawValue, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hkRef)
        if status == noErr {
            ref = hkRef
        } else {
            print("[GlobalHotkey] Kunne ikke registrere hotkey: \(status)")
        }
    }

    deinit {
        if let ref = ref {
            UnregisterEventHotKey(ref)
        }
        Self.handlers.removeValue(forKey: id)
    }

    // MARK: - Carbon plumbing

    /// "JMVO" som FourCharCode - bruges som signature så vores hotkey events
    /// ikke kolliderer med andres på samme proces.
    private static let signature: OSType = {
        let chars: [UInt8] = [0x4A, 0x4D, 0x56, 0x4F] // J M V O
        return OSType(chars[0]) << 24 | OSType(chars[1]) << 16 | OSType(chars[2]) << 8 | OSType(chars[3])
    }()

    private static func installCarbonHandlerIfNeeded() {
        guard !carbonHandlerInstalled else { return }
        carbonHandlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                            EventParamType(typeEventHotKeyID), nil,
                                            MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr, let handler = GlobalHotkey.handlers[hotKeyID.id] {
                DispatchQueue.main.async { handler() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
