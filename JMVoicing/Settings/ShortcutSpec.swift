import Foundation
import AppKit
import Carbon.HIToolbox

/// Repræsenterer en almindelig genvej: en tast + et eller flere modifier-flags.
/// Modsat DictationTrigger (som er en modifier-only push-to-talk tast),
/// bruges ShortcutSpec til "almindelige" hotkeys som ⌃⌥G og ⌃⌥A.
struct ShortcutSpec: Codable, Equatable {
    /// Carbon virtual key code (samme nummerering som NSEvent.keyCode).
    let keyCode: UInt32

    /// OR'ed Carbon modifier flags (cmdKey, optionKey, controlKey, shiftKey).
    let modifiers: UInt32

    /// Cosmetic label til UI'et - fx "G", "Space", "F2".
    /// Round-trip-uafhængig: hvis label går tabt, kan vi genskabe noget brugbart.
    let label: String

    /// Display-form til menubar og settings, fx "⌃⌥G".
    var display: String {
        var parts = ""
        if modifiers & UInt32(controlKey) != 0 { parts += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { parts += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { parts += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { parts += "⌘" }
        parts += label.isEmpty ? "·" : label
        return parts
    }

    // MARK: - Defaults

    static let defaultGrammar = ShortcutSpec(
        keyCode: 5,  // G
        modifiers: UInt32(controlKey | optionKey),
        label: "G"
    )

    static let defaultCommand = ShortcutSpec(
        keyCode: 0,  // A
        modifiers: UInt32(controlKey | optionKey),
        label: "A"
    )

    // MARK: - Capture fra NSEvent

    /// Bygger en ShortcutSpec fra et keyDown event. Returnerer nil hvis der
    /// ikke er nogen modifier - vi tillader ikke "bare en bogstavtast" som
    /// global genvej (den ville aktivere hver gang du bare skrev).
    static func from(nsEvent event: NSEvent) -> ShortcutSpec? {
        var mods: UInt32 = 0
        if event.modifierFlags.contains(.command)  { mods |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option)   { mods |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control)  { mods |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift)    { mods |= UInt32(shiftKey) }
        guard mods != 0 else { return nil }

        return ShortcutSpec(
            keyCode: UInt32(event.keyCode),
            modifiers: mods,
            label: Self.label(for: event)
        )
    }

    private static func label(for event: NSEvent) -> String {
        // Special-keys der ikke har en pæn "characters"-repræsentation.
        switch Int(event.keyCode) {
        case kVK_Space:       return "Space"
        case kVK_Return:      return "↩"
        case kVK_Tab:         return "⇥"
        case kVK_Delete:      return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape:      return "⎋"
        case kVK_LeftArrow:   return "←"
        case kVK_RightArrow:  return "→"
        case kVK_DownArrow:   return "↓"
        case kVK_UpArrow:     return "↑"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: break
        }

        let chars = event.charactersIgnoringModifiers ?? ""
        return chars.uppercased()
    }
}

/// Push-to-talk tasten til dictation. Modifier-only key, ingen tegn-tast.
/// Vi understøtter et udvalg af modifier-keys som ikke kolliderer typisk
/// med systemet (vi anbefaler Fn/🌐 eller Højre ⌥).
enum DictationTrigger: String, CaseIterable, Identifiable, Codable {
    case fn
    case rightOption
    case rightControl
    case rightShift
    case rightCommand
    case leftOption
    case leftControl
    case leftShift
    case leftCommand

    var id: String { rawValue }

    /// Virtual key code som flagsChanged-eventet rapporterer.
    var keyCode: Int64 {
        switch self {
        case .fn:           return 63
        case .rightOption:  return 61
        case .rightControl: return 62
        case .rightShift:   return 60
        case .rightCommand: return 54
        case .leftOption:   return 58
        case .leftControl:  return 59
        case .leftShift:    return 56
        case .leftCommand:  return 55
        }
    }

    var display: String {
        switch self {
        case .fn:           return "Fn / 🌐"
        case .rightOption:  return "Højre ⌥ (option)"
        case .rightControl: return "Højre ⌃ (control)"
        case .rightShift:   return "Højre ⇧ (shift)"
        case .rightCommand: return "Højre ⌘ (command)"
        case .leftOption:   return "Venstre ⌥ (option)"
        case .leftControl:  return "Venstre ⌃ (control)"
        case .leftShift:    return "Venstre ⇧ (shift)"
        case .leftCommand:  return "Venstre ⌘ (command)"
        }
    }

    /// Kort kompakt label til menu bar og knapper, fx "Højre ⌥".
    var shortDisplay: String {
        switch self {
        case .fn:           return "Fn / 🌐"
        case .rightOption:  return "Højre ⌥"
        case .rightControl: return "Højre ⌃"
        case .rightShift:   return "Højre ⇧"
        case .rightCommand: return "Højre ⌘"
        case .leftOption:   return "Venstre ⌥"
        case .leftControl:  return "Venstre ⌃"
        case .leftShift:    return "Venstre ⇧"
        case .leftCommand:  return "Venstre ⌘"
        }
    }
}
