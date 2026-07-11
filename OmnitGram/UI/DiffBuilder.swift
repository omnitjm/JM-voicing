import AppKit

/// Bygger en farvemarkeret ord-diff mellem original og rettet tekst:
/// slettede ord i rødt med gennemstregning, tilføjede ord i grønt.
/// Bruges i preview-panelet så brugeren kan se præcis hvad der ændres.
enum DiffBuilder {

    enum Segment {
        case same(String)
        case removed(String)
        case inserted(String)
    }

    /// Ord-niveau diff via Swifts indbyggede CollectionDifference.
    /// Tokeniserer på whitespace men bevarer linjeskift som egne tokens,
    /// så afsnitsstruktur forbliver synlig i previewet.
    static func diff(original: String, corrected: String) -> [Segment] {
        let oldTokens = tokenize(original)
        let newTokens = tokenize(corrected)

        let difference = newTokens.difference(from: oldTokens)
        var removedAt = Set<Int>()
        var insertedAt = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removedAt.insert(offset)
            case .insert(let offset, _, _): insertedAt.insert(offset)
            }
        }

        var segments: [Segment] = []
        var i = 0  // index i oldTokens
        var j = 0  // index i newTokens
        while i < oldTokens.count || j < newTokens.count {
            if i < oldTokens.count && removedAt.contains(i) {
                segments.append(.removed(oldTokens[i]))
                i += 1
            } else if j < newTokens.count && insertedAt.contains(j) {
                segments.append(.inserted(newTokens[j]))
                j += 1
            } else if i < oldTokens.count && j < newTokens.count {
                segments.append(.same(newTokens[j]))
                i += 1
                j += 1
            } else {
                // Bør ikke ske hvis diffen er konsistent, men vær robust.
                break
            }
        }
        return coalesce(segments)
    }

    /// Render diff-segmenter til en NSAttributedString til visning i previewet.
    static func attributedString(for segments: [Segment]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: 14)

        let sameAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let removedAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemRed,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ]
        let insertedAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.systemGreen
        ]

        for (index, segment) in segments.enumerated() {
            let needsSpace = index > 0
            switch segment {
            case .same(let text):
                if needsSpace && text != "\n" { result.append(NSAttributedString(string: " ", attributes: sameAttrs)) }
                result.append(NSAttributedString(string: text, attributes: sameAttrs))
            case .removed(let text):
                if needsSpace && text != "\n" { result.append(NSAttributedString(string: " ", attributes: sameAttrs)) }
                if text != "\n" {
                    result.append(NSAttributedString(string: text, attributes: removedAttrs))
                }
            case .inserted(let text):
                if needsSpace && text != "\n" { result.append(NSAttributedString(string: " ", attributes: sameAttrs)) }
                result.append(NSAttributedString(string: text, attributes: insertedAttrs))
            }
        }
        return result
    }

    // MARK: - Helpers

    /// Splitter i ord-tokens; runs af whitespace kollapses, men linjeskift
    /// bevares som selvstændige "\n"-tokens.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for char in text {
            if char == "\n" {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append("\n")
            } else if char.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Slår naboer af samme type sammen så attributed-string-bygningen
    /// (og evt. fremtidig styling) arbejder med færre segmenter.
    private static func coalesce(_ segments: [Segment]) -> [Segment] {
        var result: [Segment] = []
        for segment in segments {
            switch (result.last, segment) {
            case (.some(.same(let a)), .same(let b)) where a != "\n" && b != "\n":
                result[result.count - 1] = .same(a + " " + b)
            case (.some(.removed(let a)), .removed(let b)) where a != "\n" && b != "\n":
                result[result.count - 1] = .removed(a + " " + b)
            case (.some(.inserted(let a)), .inserted(let b)) where a != "\n" && b != "\n":
                result[result.count - 1] = .inserted(a + " " + b)
            default:
                result.append(segment)
            }
        }
        return result
    }
}
