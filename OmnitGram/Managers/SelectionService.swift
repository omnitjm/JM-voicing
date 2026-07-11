import AppKit

/// Læser den markerede tekst fra hvilken som helst app via pasteboard-tricket:
/// gem pasteboard → simulér ⌘C → læs → gendan pasteboard.
/// Kræver Accessibility-tilladelse.
enum SelectionService {

    /// Returnerer markeret tekst, eller nil hvis der ikke var noget markeret.
    static func readSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let originalChangeCount = pasteboard.changeCount

        // Gem nuværende pasteboard-indhold så vi kan gendanne det
        let savedItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []

        // Lad brugeren slippe genvejens modifier-taster, ellers bliver vores
        // simulerede ⌘C til fx ⌃⌥⌘C i nogle apps.
        try? await Task.sleep(nanoseconds: 150_000_000)

        // Simulér ⌘C
        simulateCmdC()

        // Vent på at pasteboard opdaterer. Op til ~300ms, polling hver 30ms.
        var newText: String?
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            if pasteboard.changeCount != originalChangeCount {
                newText = pasteboard.string(forType: .string)
                break
            }
        }

        // Gendan oprindeligt pasteboard-indhold
        pasteboard.clearContents()
        if !savedItems.isEmpty {
            pasteboard.writeObjects(savedItems)
        }

        guard let text = newText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    private static func simulateCmdC() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 8

        // Session-tap frem for HID-tap: injicerer i brugerens login-session,
        // hvilket router mere pålideligt til den aktive app.
        let down = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cgSessionEventTap)
    }
}
