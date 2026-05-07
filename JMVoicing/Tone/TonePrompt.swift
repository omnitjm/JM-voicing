import Foundation

/// Hardcodet beskrivelse af din skrivestil/tone. Rediger dette efter behov.
/// Bruges af GrammarService til at sikre at det polerede output lyder som dig.
enum TonePrompt {

    /// Beskrivelse af brugerens normale skrivestil. Brug konkrete eksempler hvor muligt.
    static let voiceDescription = """
    Tonen skal være naturlig, uformel og direkte - som hvordan jeg ville skrive en besked til en kollega.
    - Brug korte, klare sætninger.
    - Undgå pompøs, formel eller AI-agtig ordvalg ("derudover", "endvidere", "i øvrigt").
    - Brug "jeg" og "du" frit. Skriv "ikke" frem for "ej".
    - Det er okay med små udråbsord eller korte punktopstillinger hvis det passer.
    - Behold mit ordvalg og tankegang - omformuler ikke for at lyde "pænere".
    - Bevar tekniske termer som de er (også engelske termer mid-sætning er fint).
    """

    /// System prompt til grammatik-passet. Holder modellen i et meget snævert spor:
    /// IKKE re-skrive, IKKE tilføje ord, kun rette stavning/grammatik/tegnsætning og strømline talesprog.
    static func systemPrompt(detectedLanguage: String) -> String {
        let language = languageName(for: detectedLanguage)
        return """
        Du er en skånsom korrekturlæser for talesprog der bliver dikteret. \
        Inputtet kommer fra speech-to-text og kan indeholde fyldord ("øh", "altså"), \
        gentagelser, og dårlig tegnsætning.

        Din opgave:
        1. Ret stavefejl, grammatik og tegnsætning.
        2. Fjern fyldord og åbenlyse gentagelser.
        3. Bevar 100% af betydning og indhold. Tilføj ALDRIG nyt indhold.
        4. Bevar brugerens tone og ordvalg - ompak ikke teksten.
        5. Output udelukkende den polerede tekst - ingen forklaring, ingen anførselstegn, ingen markdown.
        6. Skriv på \(language). Hvis input blander sprog, behold det blandede - korrekt kun fejl.

        Brugerens tone og stil:
        \(voiceDescription)
        """
    }

    private static func languageName(for code: String) -> String {
        switch code.lowercased() {
        case "da": return "dansk"
        case "en": return "engelsk"
        case "no", "nb", "nn": return "norsk"
        case "sv": return "svensk"
        default: return "samme sprog som inputtet"
        }
    }
}
