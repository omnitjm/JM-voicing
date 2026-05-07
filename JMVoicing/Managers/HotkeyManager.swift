import AppKit
import Carbon.HIToolbox

/// Lytter efter Fn / Globus tasten via en CGEvent tap.
/// Push-to-talk: kalder onPress når Fn trykkes, onRelease når Fn slippes.
///
/// VIGTIGT: Kræver Accessibility-tilladelse i System Settings → Privacy & Security → Accessibility.
/// VIGTIGT: macOS' indbyggede Fn-dictation skal være slået fra:
///   System Settings → Keyboard → Press Fn key to: → "Do Nothing"
///   System Settings → Keyboard → Dictation: Off
final class HotkeyManager {
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnIsDown = false

    init(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    func start() {
        guard ensureAccessibility() else {
            print("[HotkeyManager] Mangler Accessibility-tilladelse.")
            return
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        )

        guard let tap = tap else {
            print("[HotkeyManager] Kunne ikke oprette event tap.")
            return
        }
        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] Lytter efter Fn-tast.")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }
        let flags = event.flags
        let fnDown = flags.contains(.maskSecondaryFn)

        if fnDown && !fnIsDown {
            fnIsDown = true
            DispatchQueue.main.async { [weak self] in self?.onPress() }
        } else if !fnDown && fnIsDown {
            fnIsDown = false
            DispatchQueue.main.async { [weak self] in self?.onRelease() }
        }
    }

    @discardableResult
    private func ensureAccessibility() -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(opts)
    }
}
