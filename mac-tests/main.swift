// E2E-test af Mac'ens OS-integrationslag (CGEvent ⌘C/⌘V) mod et rigtigt
// NSTextView. Deler SelectionService og TextInserter med selve appen, så det
// er PRÆCIS produktionskoden der testes.
//
// Flow:
//   1. Åbn vindue med NSTextView der indeholder "hello wrold", markér alt
//   2. SelectionService.readSelectedText() -> ægte ⌘C gennem OS'et
//   3. TextInserter.insert("hello world")  -> ægte ⌘V gennem OS'et
//   4. Assert: feltet indeholder den nye tekst, og clipboard er gendannet
//
// Kræver Accessibility. Hvis processen ikke er trusted (fx en runner hvor
// TCC-grant fejlede), exiter vi 0 med en MEGET tydelig SKIPPED-advarsel -
// vi vil hellere have et ærligt "kunne ikke køres her" end en rød pipeline
// på grund af runner-miljøet.

import AppKit
import ApplicationServices

let ORIGINAL_CLIPBOARD = "forudgaaende clipboard-indhold"
let WRONG_TEXT = "hello wrold"
let FIXED_TEXT = "hello world"

guard AXIsProcessTrusted() else {
    print("::warning::E2E SKIPPED: processen har ikke Accessibility-tilladelse på denne runner")
    print("E2E SKIPPED")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let window = NSWindow(
    contentRect: NSRect(x: 200, y: 200, width: 420, height: 160),
    styleMask: [.titled],
    backing: .buffered,
    defer: false
)
window.title = "OmnitGram e2e target"

let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 420, height: 160))
textView.string = WRONG_TEXT
textView.isEditable = true
window.contentView = textView

window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
window.makeFirstResponder(textView)
textView.setSelectedRange(NSRange(location: 0, length: (WRONG_TEXT as NSString).length))

NSPasteboard.general.clearContents()
NSPasteboard.general.setString(ORIGINAL_CLIPBOARD, forType: .string)

func fail(_ message: String) -> Never {
    print("E2E FAILED: \(message)")
    exit(1)
}

Task {
    // Lad vinduet blive aktivt og first responder falde på plads.
    try? await Task.sleep(nanoseconds: 1_500_000_000)

    // 1) Læs markering via ægte ⌘C
    let selected = await SelectionService.readSelectedText()
    guard selected == WRONG_TEXT else {
        fail("readSelectedText gav \(selected ?? "nil"), forventede \(WRONG_TEXT)")
    }

    // 2) Indsæt rettet tekst via ægte ⌘V (erstatter den aktive markering)
    await MainActor.run {
        TextInserter.insert(FIXED_TEXT)
    }

    // Vent på paste (+0.05s) og clipboard-gendannelse (+0.65s)
    try? await Task.sleep(nanoseconds: 1_800_000_000)

    // 3) Verificér feltets indhold
    let content = await MainActor.run { textView.string }
    guard content == FIXED_TEXT else {
        fail("tekstfeltet indeholder \(content), forventede \(FIXED_TEXT)")
    }

    // 4) Verificér at det oprindelige clipboard er gendannet
    let clip = NSPasteboard.general.string(forType: .string)
    guard clip == ORIGINAL_CLIPBOARD else {
        fail("clipboard er \(clip ?? "nil"), forventede gendannet \(ORIGINAL_CLIPBOARD)")
    }

    print("E2E OK: markering laest, tekst erstattet, clipboard gendannet")
    exit(0)
}

// Failsafe: hvis noget hænger, dræb testen efter 30s med fejl.
DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
    fail("timeout efter 30s")
}

app.run()
