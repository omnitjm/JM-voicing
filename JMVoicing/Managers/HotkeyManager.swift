import AppKit
import Carbon.HIToolbox

/// Lytter efter push-to-talk-tasten. Hvilken tast er valgt af brugeren via Settings
/// (default: Fn). Tasten skal være en modifier-only tast - vi bruger CGEventTap til
/// at fange den, men "stjæler" den ikke (.listenOnly) så macOS' egne genveje stadig
/// virker.
///
/// VIGTIGT: Kræver Accessibility-tilladelse i System Settings → Privacy & Security
/// → Accessibility. Hvis brugeren vælger Fn, skal macOS' indbyggede Fn-dictation
/// også slås fra under System Settings → Keyboard.
final class HotkeyManager {
    private let onPress: () -> Void
    private let onRelease: () -> Void
    private var trigger: DictationTrigger
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isHeld = false

    init(trigger: DictationTrigger,
         onPress: @escaping () -> Void,
         onRelease: @escaping () -> Void) {
        self.trigger = trigger
        self.onPress = onPress
        self.onRelease = onRelease
    }

    /// Skift hvilken tast vi lytter efter. Nulstiller intern state så vi ikke
    /// bliver "fastfrosset" hvis brugeren skiftede mens den gamle tast var nede.
    func update(trigger: DictationTrigger) {
        self.trigger = trigger
        self.isHeld = false
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
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard type == .flagsChanged else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == trigger.keyCode else { return }

        // Toggle - macOS sender præcis ét flagsChanged-event pr. transition for
        // den specifikke fysiske tast (identificeret af keyCode), så simpel
        // toggling er nok. Hvis app'en startes mens tasten holdes nede, vil
        // første event blive tolket som press, men brugeren slipper og holder
        // igen og alt er fint.
        isHeld.toggle()
        if isHeld {
            DispatchQueue.main.async { [weak self] in self?.onPress() }
        } else {
            DispatchQueue.main.async { [weak self] in self?.onRelease() }
        }
    }

    @discardableResult
    private func ensureAccessibility() -> Bool {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(opts)
    }
}
