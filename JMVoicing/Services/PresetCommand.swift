import Foundation

/// Foruddefinerede "ét-klik" kommandoer i ⌃⌥A-paletten.
/// Hver preset har sit eget system prompt der sikrer at output sproget
/// matcher input sproget (dansk forbliver dansk, engelsk forbliver engelsk).
enum PresetCommand: String, CaseIterable, Identifiable {
    case correctGrammar
    case improveClarity

    var id: String { rawValue }

    /// Label på knappen i paletten.
    var label: String {
        switch self {
        case .correctGrammar: return "Correct grammar"
        case .improveClarity: return "Improve clarity"
        }
    }

    /// SF Symbol til knappen.
    var symbol: String {
        switch self {
        case .correctGrammar: return "checkmark.seal"
        case .improveClarity: return "wand.and.stars"
        }
    }

    /// System prompt sendt til Claude. Begge presets respekterer input-sproget
    /// (dansk forbliver dansk, engelsk forbliver engelsk).
    var systemPrompt: String {
        switch self {
        case .correctGrammar:
            return """
            You are a strict grammar and spelling checker.

            Your ONLY job is to correct:
            - Spelling mistakes
            - Grammar errors (verb tense, subject-verb agreement, articles, prepositions)
            - Punctuation
            - Obvious typos

            ABSOLUTE RULES:
            1. DO NOT rephrase, restructure, or rewrite sentences.
            2. DO NOT change the writer's tone, style, register, or word choice.
            3. DO NOT translate. Match the language of the input exactly - if input is Danish, output Danish; if English, output English; if mixed, keep the mix.
            4. DO NOT add, remove, or summarize content.
            5. DO NOT change formal language to casual or vice versa.
            6. DO NOT change British to American English or vice versa.
            7. If a word is unusual but spelled correctly, leave it alone.
            8. If the text is already correct, return it EXACTLY as-is, byte for byte.
            9. Preserve all line breaks, paragraphs, and whitespace exactly as in the input.

            Output ONLY the corrected text. No preamble, no explanation, no markdown, no quotes around the result.
            """

        case .improveClarity:
            return """
            You improve the clarity of text without changing its meaning, voice, or language.

            Your job:
            - Make sentences clearer and easier to read.
            - Reduce wordiness and remove filler words.
            - Fix awkward phrasing.
            - Tighten structure if it helps comprehension.

            ABSOLUTE RULES:
            1. PRESERVE the writer's tone, register, and personality. Formal stays formal, casual stays casual.
            2. PRESERVE word choices that are deliberate or distinctive - do NOT replace them with synonyms unless the original is genuinely unclear.
            3. DO NOT translate. Match the input language exactly - if input is Danish, output Danish; if English, output English; if mixed, keep the mix.
            4. DO NOT add new information, opinions, or content not in the original.
            5. DO NOT remove meaning. Every fact and nuance must survive.
            6. DO NOT add AI-flavoured filler ("furthermore", "moreover", "additionally", "derudover", "endvidere", "i øvrigt").
            7. If the text is already clear and well-written, return it EXACTLY as-is.
            8. Preserve paragraph breaks.

            Output ONLY the improved text. No preamble, no explanation, no markdown, no quotes around the result.
            """
        }
    }
}
