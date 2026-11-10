//
//  AttributedParagraphs.swift
//  JustText
//
//  Splits an attributed string into paragraphs for the export writers.
//

import Foundation

enum AttributedParagraphs {
    /// Matches a leading list marker (bullet, dash, checkbox, or "N.") plus its
    /// tab, exactly as `FormattingTextView` inserts them.
    static let listMarkerRegex = try! NSRegularExpression(
        pattern: "(?:[•\\u2013\\-\\u2610\\u2611]|[0-9]+\\.)\\t"
    )

    /// Returns every paragraph of `attributedString` without its trailing
    /// newline. An empty string yields a single empty paragraph.
    static func paragraphs(of attributedString: NSAttributedString) -> [NSAttributedString] {
        guard attributedString.length > 0 else { return [NSAttributedString(string: "")] }

        var paragraphs: [NSAttributedString] = []
        let fullString = attributedString.string as NSString
        fullString.enumerateSubstrings(
            in: NSRange(location: 0, length: fullString.length),
            options: [.byParagraphs, .substringNotRequired]
        ) { _, paragraphRange, _, _ in
            var range = paragraphRange
            if range.length > 0 && fullString.substring(with: NSRange(location: range.location + range.length - 1, length: 1)) == "\n" {
                range.length -= 1
            }
            paragraphs.append(attributedString.attributedSubstring(from: range))
        }

        return paragraphs
    }
}
