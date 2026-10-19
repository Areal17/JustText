//
//  MarkdownWriter.swift
//  JustText
//
//  Converts a JustText document into Markdown.
//

import AppKit
import Foundation

enum MarkdownWriter {
    static func markdown(from attributedString: NSAttributedString) -> String {
        var output = ""
        var previousKind: BlockKind?

        for paragraph in AttributedParagraphs.paragraphs(of: attributedString) {
            guard let block = block(from: paragraph) else { continue }

            if let previousKind {
                // List items and quote lines stay together; everything else
                // is separated by a blank line.
                let isContinued = previousKind == block.kind && block.kind != .paragraph && block.kind != .heading
                output += isContinued ? "\n" : "\n\n"
            }
            output += block.text
            previousKind = block.kind
        }

        return output.isEmpty ? "" : output + "\n"
    }

    // MARK: - Blocks

    private enum BlockKind {
        case list, quote, heading, paragraph
    }

    private struct Block {
        let kind: BlockKind
        let text: String
    }

    /// Matches a leading list marker (bullet, dash, checkbox, or "N.") plus its tab,
    /// exactly as `FormattingTextView` inserts them.
    private static let markerRegex = try! NSRegularExpression(
        pattern: "(?:[•\\u2013\\-\\u2610\\u2611]|[0-9]+\\.)\\t"
    )

    /// Classifies a paragraph and renders it. Returns `nil` for paragraphs
    /// without any visible content.
    private static func block(from paragraph: NSAttributedString) -> Block? {
        let string = paragraph.string as NSString

        if let match = markerRegex.firstMatch(
            in: paragraph.string,
            options: .anchored,
            range: NSRange(location: 0, length: string.length)
        ) {
            let marker = string.substring(with: match.range).trimmingCharacters(in: .whitespaces)
            let content = paragraph.attributedSubstring(
                from: NSRange(location: match.range.length, length: string.length - match.range.length)
            )
            guard hasVisibleContent(content) else { return nil }
            return Block(kind: .list, text: listPrefix(for: marker) + inlineMarkdown(from: content))
        }

        guard hasVisibleContent(paragraph) else { return nil }

        if isQuote(paragraph) {
            return Block(kind: .quote, text: "> " + inlineMarkdown(from: paragraph))
        }

        if let level = headingLevel(of: paragraph) {
            let title = escapedLineStart(escaped(paragraph.string.trimmingCharacters(in: .whitespaces)))
            return Block(kind: .heading, text: String(repeating: "#", count: level) + " " + title)
        }

        return Block(kind: .paragraph, text: inlineMarkdown(from: paragraph))
    }

    private static func listPrefix(for marker: String) -> String {
        switch marker {
        case "☐":
            "- [ ] "
        case "☑":
            "- [x] "
        case "•", "–", "-":
            "- "
        default:
            marker + " "   // "N."
        }
    }

    private static func hasVisibleContent(_ attributedString: NSAttributedString) -> Bool {
        attributedString.string.contains { !$0.isWhitespace }
    }

    private static func isQuote(_ paragraph: NSAttributedString) -> Bool {
        guard let style = paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle else {
            return false
        }
        return style.firstLineHeadIndent > 0 && style.headIndent > 0
    }

    /// Maps the Title / Heading / Subheading presets (28 / 20 / 15 pt) to
    /// Markdown heading levels. Thresholds instead of exact sizes, so fonts
    /// chosen in the font panel are recognized as well.
    private static func headingLevel(of paragraph: NSAttributedString) -> Int? {
        guard let font = paragraph.attribute(.font, at: 0, effectiveRange: nil) as? NSFont else { return nil }

        switch font.pointSize {
        case 24...:
            return 1
        case 18..<24:
            return 2
        case 15..<18:
            return 3
        default:
            return nil
        }
    }

    // MARK: - Inline formatting

    private struct Segment {
        var text: String
        let isBold: Bool
        let isItalic: Bool
    }

    private static func inlineMarkdown(from attributedString: NSAttributedString) -> String {
        // Merge adjacent runs with the same emphasis (e.g. two bold fonts of
        // different families), otherwise the output would contain "****".
        var segments: [Segment] = []
        attributedString.enumerateAttribute(
            .font,
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, range, _ in
            let text = attributedString.attributedSubstring(from: range).string
            let traits = (value as? NSFont).map { NSFontManager.shared.traits(of: $0) } ?? []
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)

            if let last = segments.last, last.isBold == isBold, last.isItalic == isItalic {
                segments[segments.count - 1].text += text
            } else {
                segments.append(Segment(text: text, isBold: isBold, isItalic: isItalic))
            }
        }

        let markdown = segments.map(render).joined()
        return escapedLineStart(markdown)
    }

    /// Wraps a segment in emphasis markers. Leading and trailing whitespace
    /// stays outside the markers, because Markdown ignores `** bold **`.
    private static func render(_ segment: Segment) -> String {
        let delimiter = switch (segment.isBold, segment.isItalic) {
        case (true, true): "***"
        case (true, false): "**"
        case (false, true): "*"
        case (false, false): ""
        }

        let core = segment.text.trimmingCharacters(in: .whitespaces)
        guard !delimiter.isEmpty, !core.isEmpty else { return escaped(segment.text) }

        let leading = String(segment.text.prefix { $0.isWhitespace })
        let trailing = String(segment.text.reversed().prefix { $0.isWhitespace }.reversed())
        return leading + delimiter + escaped(core) + delimiter + trailing
    }

    // MARK: - Escaping

    private static func escaped(_ text: String) -> String {
        var result = ""
        for character in text {
            if "\\*_`".contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }

    private static let orderedListStartRegex = try! NSRegularExpression(pattern: "^([0-9]+)\\.(?=\\s|$)")

    /// Prevents text that merely looks like Markdown syntax at the start of a
    /// line ("# tag", "> note", "- item", "1. item") from being interpreted.
    private static func escapedLineStart(_ text: String) -> String {
        if let first = text.first, "#>-+".contains(first) {
            return "\\" + text
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        return orderedListStartRegex.stringByReplacingMatches(in: text, range: range, withTemplate: "$1\\\\.")
    }
}
