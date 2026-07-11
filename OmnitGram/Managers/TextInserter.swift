import AppKit
import Carbon.HIToolbox

/// Indsætter tekst der hvor markøren står - i hvilken som helst app.
/// Strategi: Gem nuværende pasteboard → læg tekst på pasteboard → simulér ⌘V → gendan pasteboard.
/// Kræver Accessibility-tilladelse.
enum TextInserter {

    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Lille forsinkelse for at give pasteboardet tid til at opdatere.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            simulateCmdV()

            // Gendan pasteboard efter pastet er sket. Rundhåndet delay så
            // langsomme apps (Electron, browsere) når at læse vores tekst først.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                pasteboard.clearContents()
                if !savedItems.isEmpty {
                    pasteboard.writeObjects(savedItems)
                }
            }
        }
    }

    private static func simulateCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9  // 'v'

        // Session-tap frem for HID-tap: injicerer i brugerens login-session,
        // hvilket router mere pålideligt til den aktive app.
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cgSessionEventTap)
    }
}
