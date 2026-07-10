import Foundation
import Carbon.HIToolbox
import AppKit

/// Registrér globale tastatur-genveje via Carbon's RegisterEventHotKey.
/// I modsætning til CGEventTap (som vi bruger til Fn) "stjæler" disse genveje
/// tastetrykket fra andre apps, så fx ⌃⌥G ikke når frem til Slack når vores
/// genvej rammer.
///
/// Genveje skal være key+modifier (ikke modifier-only). Ny instans pr. genvej;
/// deinit unregisterer automatisk.
final class GlobalHotkey {

    private static var handlers: [UInt32: () -> Void] = [:]
    private static var nextId: UInt32 = 1
    private static var carbonHandlerInstalled = false

    private var ref: EventHotKeyRef?
    private let id: UInt32

    /// keyCode er en Carbon/NSEvent virtual key code. modifiers er OR'ed Carbon
    /// modifier-flags (cmdKey, optionKey, controlKey, shiftKey).
    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        guard modifiers != 0 else {
            print("[GlobalHotkey] Afviser hotkey uden modifier - ville aktivere når du skriver.")
            return nil
        }

        id = Self.nextId
        Self.nextId += 1
        Self.handlers[id] = handler
        Self.installCarbonHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var hkRef: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &hkRef)
        if status == noErr {
            ref = hkRef
        } else {
            print("[GlobalHotkey] Kunne ikke registrere hotkey (\(keyCode)+\(modifiers)): \(status)")
            Self.handlers.removeValue(forKey: id)
            return nil
        }
    }

    /// Convenience-init med ShortcutSpec.
    convenience init?(spec: ShortcutSpec, handler: @escaping () -> Void) {
        self.init(keyCode: spec.keyCode, modifiers: spec.modifiers, handler: handler)
    }

    deinit {
        if let ref = ref {
            UnregisterEventHotKey(ref)
        }
        Self.handlers.removeValue(forKey: id)
    }

    // MARK: - Carbon plumbing

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
