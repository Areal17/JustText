//
//  FormattingTextView.swift
//  JustText
//
//  An NSTextView subclass (TextKit 2) that exposes paragraph-level
//  formatting actions for the "Format" menu. The actions are plain
//  `@objc` responder-chain methods, so menu items with a `nil` target
//  are automatically routed to whichever text view is first responder.
//

import AppKit

final class FormattingTextView: NSTextView {

    // MARK: - Default ("normal") text style

    /// The font used for normal body text (matches the editor default).
    static let defaultBodyFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// The typing attributes for normal, unformatted text.
    static let defaultTypingAttributes: [NSAttributedString.Key: Any] = [
        .font: defaultBodyFont,
        .paragraphStyle: NSParagraphStyle.default
    ]

    /// Starting a new line resets the format back to normal text, so that a
    /// heading or list style doesn't carry over into the next paragraph.
    override func insertNewline(_ sender: Any?) {
        super.insertNewline(sender)
        typingAttributes = Self.defaultTypingAttributes
    }

    // MARK: - Font presets

    @objc func applyTitleStyle(_ sender: Any?) {
        restyleParagraphs(marker: .none,
                          paragraphStyle: .default,
                          font: .systemFont(ofSize: 28, weight: .bold))
    }

    @objc func applyHeadingStyle(_ sender: Any?) {
        restyleParagraphs(marker: .none,
                          paragraphStyle: .default,
                          font: .systemFont(ofSize: 20, weight: .bold))
    }

    @objc func applySubheadingStyle(_ sender: Any?) {
        restyleParagraphs(marker: .none,
                          paragraphStyle: .default,
                          font: .systemFont(ofSize: 15, weight: .semibold))
    }

    /// "Text" – the default body style (monospaced, matching the editor default).
    @objc func applyBodyStyle(_ sender: Any?) {
        restyleParagraphs(marker: .none,
                          paragraphStyle: .default,
                          font: Self.defaultBodyFont)
    }

    /// "Proportional" – body size using the proportional system font.
    @objc func applyProportionalStyle(_ sender: Any?) {
        restyleParagraphs(marker: .none,
                          paragraphStyle: .default,
                          font: .systemFont(ofSize: NSFont.systemFontSize))
    }

    // MARK: - Lists

    @objc func applyBulletList(_ sender: Any?) {
        restyleParagraphs(marker: .bullet, paragraphStyle: Self.listParagraphStyle, font: nil)
    }

    @objc func applyDashList(_ sender: Any?) {
        restyleParagraphs(marker: .dash, paragraphStyle: Self.listParagraphStyle, font: nil)
    }

    @objc func applyNumberedList(_ sender: Any?) {
        restyleParagraphs(marker: .numbered, paragraphStyle: Self.listParagraphStyle, font: nil)
    }

    @objc func applyChecklist(_ sender: Any?) {
        restyleParagraphs(marker: .checkbox, paragraphStyle: Self.listParagraphStyle, font: nil)
    }

    // MARK: - Quote

    @objc func applyQuoteBlock(_ sender: Any?) {
        restyleParagraphs(marker: .none, paragraphStyle: Self.quoteParagraphStyle, font: nil)
    }

    // MARK: - Line markers

    private enum LineMarker {
        case none, bullet, dash, numbered, checkbox

        func text(for index: Int) -> String {
            switch self {
            case .none:     return ""
            case .bullet:   return "•\t"
            case .dash:     return "–\t"
            case .numbered: return "\(index + 1).\t"
            case .checkbox: return "☐\t"
            }
        }
    }

    /// Matches a leading list marker (bullet, dash, checkbox, or "N.") plus its tab.
    private static let markerRegex = try! NSRegularExpression(
        pattern: "(?:[•\\u2013\\-\\u2610\\u2611]|[0-9]+\\.)\\t"
    )

    private func stripLeadingMarker(_ line: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: line.length)
        if let match = Self.markerRegex.firstMatch(in: line.string, options: .anchored, range: range) {
            line.deleteCharacters(in: match.range)
        }
    }

    // MARK: - Paragraph styles

    private static let listParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 0
        style.headIndent = 22
        style.tabStops = [NSTextTab(textAlignment: .left, location: 22)]
        style.defaultTabInterval = 22
        return style
    }()

    private static let quoteParagraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 24
        style.headIndent = 24
        style.paragraphSpacing = 4
        return style
    }()

    // MARK: - Core paragraph transform

    /// Re-styles every paragraph intersecting the current selection: strips any
    /// existing list marker, inserts a new one, and applies the paragraph style
    /// (and optionally a font) across the affected range — all as a single
    /// undoable edit.
    private func restyleParagraphs(marker: LineMarker, paragraphStyle: NSParagraphStyle, font: NSFont?) {
        guard let textStorage else { return }

        let fullString = textStorage.string as NSString
        let paragraphRange = fullString.paragraphRange(for: selectedRange())
        let source = textStorage.attributedSubstring(from: paragraphRange)
        let sourceString = source.string as NSString

        let result = NSMutableAttributedString()
        var lineIndex = 0

        sourceString.enumerateSubstrings(
            in: NSRange(location: 0, length: sourceString.length),
            options: [.byLines, .substringNotRequired]
        ) { _, _, enclosingRange, _ in
            let line = NSMutableAttributedString(attributedString: source.attributedSubstring(from: enclosingRange))
            self.stripLeadingMarker(line)

            let markerText = marker.text(for: lineIndex)
            if !markerText.isEmpty {
                let attrs = line.length > 0
                    ? line.attributes(at: 0, effectiveRange: nil)
                    : self.typingAttributes
                line.insert(NSAttributedString(string: markerText, attributes: attrs), at: 0)
            }

            result.append(line)
            lineIndex += 1
        }

        // Handle an empty paragraph (e.g. cursor on a blank line).
        if result.length == 0 {
            let markerText = marker.text(for: 0)
            if !markerText.isEmpty {
                result.append(NSAttributedString(string: markerText, attributes: typingAttributes))
            }
        }

        let resultRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.paragraphStyle, value: paragraphStyle, range: resultRange)
        if let font {
            result.addAttribute(.font, value: font, range: resultRange)
        }

        guard shouldChangeText(in: paragraphRange, replacementString: result.string) else { return }
        textStorage.replaceCharacters(in: paragraphRange, with: result)
        didChangeText()

        setSelectedRange(NSRange(location: paragraphRange.location + result.length, length: 0))

        // Carry the style forward for continued typing.
        typingAttributes[.paragraphStyle] = paragraphStyle
        if let font {
            typingAttributes[.font] = font
        }
    }
}
