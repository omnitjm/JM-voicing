import Foundation
import AppKit
import Carbon.HIToolbox

/// Repræsenterer en global genvej: en tast + et eller flere modifier-flags.
struct ShortcutSpec: Codable, Equatable {
    /// Carbon virtual key code (samme nummerering som NSEvent.keyCode).
    let keyCode: UInt32

    /// OR'ed Carbon modifier flags (cmdKey, optionKey, controlKey, shiftKey).
    let modifiers: UInt32

    /// Cosmetic label til UI'et - fx "G", "Space", "F2".
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

    /// ⌃⌥G - ret grammatik
    static let defaultGrammar = ShortcutSpec(
        keyCode: 5,  // G
        modifiers: UInt32(controlKey | optionKey),
        label: "G"
    )

    /// ⌃⌥O - optimér sproget
    static let defaultImprove = ShortcutSpec(
        keyCode: 31,  // O
        modifiers: UInt32(controlKey | optionKey),
        label: "O"
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
        switch Int(event.keyCode) {
        case kVK_Space:         return "Space"
        case kVK_Return:        return "↩"
        case kVK_Tab:           return "⇥"
        case kVK_Delete:        return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape:        return "⎋"
        case kVK_LeftArrow:     return "←"
        case kVK_RightArrow:    return "→"
        case kVK_DownArrow:     return "↓"
        case kVK_UpArrow:       return "↑"
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
