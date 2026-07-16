import Foundation

/// Regex-based HTML → plain text, good enough for JD pages / blogs.
/// No WebKit dependency so it can run anywhere (including tests).
public enum HTMLTextExtractor {
    public static func plainText(from html: String) -> String {
        var s = html

        // Drop non-content blocks entirely.
        for tag in ["script", "style", "noscript", "svg", "head", "iframe"] {
            s = s.replacingOccurrences(
                of: "<\(tag)\\b[\\s\\S]*?</\(tag)>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        s = s.replacingOccurrences(
            of: "<!--[\\s\\S]*?-->",
            with: " ",
            options: .regularExpression
        )

        // Block-level closes become line breaks so structure survives.
        s = s.replacingOccurrences(
            of: "<br\\b[^>]*>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )
        s = s.replacingOccurrences(
            of: "</(p|div|li|ul|ol|h[1-6]|tr|section|article|blockquote)>",
            with: "\n",
            options: [.regularExpression, .caseInsensitive]
        )

        // Strip remaining tags.
        s = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Common entities.
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&apos;": "'",
            "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&middot;": "·"
        ]
        for (entity, char) in entities {
            s = s.replacingOccurrences(of: entity, with: char)
        }
        // Numeric entities (&#8212; etc.)
        s = decodeNumericEntities(in: s)

        // Collapse whitespace.
        s = s.replacingOccurrences(of: "[ \\t\\r]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Page <title> if present.
    public static func title(from html: String) -> String? {
        guard let range = html.range(
            of: "<title[^>]*>([\\s\\S]*?)</title>",
            options: [.regularExpression, .caseInsensitive]
        ) else { return nil }
        let raw = String(html[range])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }

    private static func decodeNumericEntities(in text: String) -> String {
        guard text.contains("&#") else { return text }
        var result = text
        let pattern = "&#(x?[0-9a-fA-F]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed()
        for match in matches {
            guard let full = Range(match.range, in: result),
                  let codeRange = Range(match.range(at: 1), in: result) else { continue }
            let code = String(result[codeRange])
            let value: UInt32?
            if code.lowercased().hasPrefix("x") {
                value = UInt32(code.dropFirst(), radix: 16)
            } else {
                value = UInt32(code)
            }
            if let value, let scalar = Unicode.Scalar(value) {
                result.replaceSubrange(full, with: String(Character(scalar)))
            }
        }
        return result
    }
}
