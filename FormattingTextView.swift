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

    /// Handles the Return key.
    ///
    /// - Inside a list, a new line continues the list with the next marker
    ///   (numbered items increment). Pressing Return again on an *empty* item
    ///   ends the list and reverts to normal text — i.e. it takes two presses.
    /// - Outside a list, a heading/quote style does not carry over: the new
    ///   line reverts to normal text immediately.
    override func insertNewline(_ sender: Any?) {
        guard let textStorage else {
            super.insertNewline(sender)
            typingAttributes = Self.defaultTypingAttributes
            return
        }

        let fullString = textStorage.string as NSString
        let paragraphRange = fullString.paragraphRange(for: selectedRange())
        var lineText = fullString.substring(with: paragraphRange)
        if lineText.hasSuffix("\n") { lineText.removeLast() }

        let lineNS = lineText as NSString
        if let match = Self.markerRegex.firstMatch(
            in: lineText,
            options: .anchored,
            range: NSRange(location: 0, length: lineNS.length)
        ) {
            let markerText = lineNS.substring(with: match.range)
            let content = lineNS.substring(from: match.range.length)
            let isEmptyItem = content.trimmingCharacters(in: .whitespaces).isEmpty

            if isEmptyItem {
                endListItem(paragraphRange: paragraphRange, in: fullString)
            } else {
                continueList(after: markerText)
            }
            return
        }

        // Not in a list: insert a newline and revert to normal text.
        super.insertNewline(sender)
        typingAttributes = Self.defaultTypingAttributes
    }

    /// Inserts a new list item after a non-empty one, carrying the marker over
    /// (and incrementing the number for ordered lists).
    private func continueList(after markerText: String) {
        guard let textStorage else { return }

        let nextMarker: String
        if let first = markerText.first, first.isNumber {
            let number = Int(markerText.prefix { $0.isNumber }) ?? 0
            nextMarker = "\(number + 1).\t"
        } else if markerText.first == "☑" {
            nextMarker = "☐\t"   // a new checklist item starts unchecked
        } else {
            nextMarker = markerText   // bullet, dash, or unchecked checkbox
        }

        let insertion = "\n" + nextMarker
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: insertion) else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: Self.defaultBodyFont,
            .paragraphStyle: Self.listParagraphStyle
        ]
        textStorage.replaceCharacters(in: range, with: NSAttributedString(string: insertion, attributes: attributes))
        didChangeText()

        setSelectedRange(NSRange(location: range.location + (insertion as NSString).length, length: 0))
        typingAttributes = attributes
    }

    /// Ends the list: removes the marker from the current (empty) item and
    /// reverts it to normal text, without adding another line.
    private func endListItem(paragraphRange: NSRange, in fullString: NSString) {
        guard let textStorage else { return }

        let paragraph = fullString.substring(with: paragraphRange)
        let replacement = paragraph.hasSuffix("\n") ? "\n" : ""

        guard shouldChangeText(in: paragraphRange, replacementString: replacement) else { return }
        textStorage.replaceCharacters(
            in: paragraphRange,
            with: NSAttributedString(string: replacement, attributes: Self.defaultTypingAttributes)
        )
        didChangeText()

        setSelectedRange(NSRange(location: paragraphRange.location, length: 0))
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

    // MARK: - Inline text styles

    @objc func applyBoldStyle(_ sender: Any?) {
        applyInlineFontTraits(.boldFontMask)
    }

    @objc func applyItalicStyle(_ sender: Any?) {
        applyInlineFontTraits(.italicFontMask)
    }

    @objc func applyBoldItalicStyle(_ sender: Any?) {
        applyInlineFontTraits([.boldFontMask, .italicFontMask])
    }

    @objc func showFontPanel(_ sender: Any?) {
        window?.makeFirstResponder(self)
        NSFontManager.shared.setSelectedFont(currentFontForFontPanel, isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(sender)
    }

    override func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else {
            super.changeFont(sender)
            return
        }

        applyFontConversion { fontManager.convert($0) }
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

    // MARK: - Copy/Paste

    /// Overrides the standard copy to copy WITHOUT formatting (plain text only).
    override func copy(_ sender: Any?) {
        guard let plainText = selectedPlainText else {
            super.copy(sender)
            return
        }

        writePlainTextToPasteboard(plainText)
    }

    /// Overrides the standard cut to cut WITHOUT formatting (plain text only).
    override func cut(_ sender: Any?) {
        guard let plainText = selectedPlainText else {
            super.cut(sender)
            return
        }

        let range = selectedRange()
        guard isEditable,
              let textStorage,
              shouldChangeText(in: range, replacementString: "") else { return }

        writePlainTextToPasteboard(plainText)
        textStorage.replaceCharacters(in: range, with: "")
        didChangeText()
        setSelectedRange(NSRange(location: range.location, length: 0))
    }

    /// Copies the selected text WITH formatting (RTF) to the pasteboard.
    /// This is invoked by the "Mit Formatierung kopieren" menu item (⇧⌘C).
    @objc func copyWithFormatting(_ sender: Any?) {
        guard let textStorage = textStorage, selectedRange().length > 0 else { return }
        
        let attributedString = textStorage.attributedSubstring(from: selectedRange())
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([attributedString])
    }

    /// Override to prevent NSTextView from automatically adding RTF data.
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        // Only allow plain text writing
        if type == .string {
            return super.writeSelection(to: pboard, type: type)
        }
        return false
    }

    private var selectedPlainText: String? {
        let range = selectedRange()
        guard range.length > 0 else { return nil }
        return (string as NSString).substring(with: range)
    }

    private func writePlainTextToPasteboard(_ plainText: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
    }

    private func applyInlineFontTraits(_ traits: NSFontTraitMask) {
        applyFontConversion { font($0, applying: traits) }
    }

    private func applyFontConversion(_ convertFont: (NSFont) -> NSFont) {
        let range = selectedRange()

        if range.length == 0 {
            let currentFont = typingAttributes[.font] as? NSFont ?? Self.defaultBodyFont
            typingAttributes[.font] = convertFont(currentFont)
            return
        }

        guard let textStorage,
              shouldChangeText(in: range, replacementString: nil) else { return }

        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: range) { value, attributeRange, _ in
            let currentFont = value as? NSFont ?? Self.defaultBodyFont
            textStorage.addAttribute(.font, value: convertFont(currentFont), range: attributeRange)
        }
        textStorage.endEditing()
        didChangeText()
    }

    private var currentFontForFontPanel: NSFont {
        let range = selectedRange()
        if range.length > 0,
           let textStorage,
           let selectedFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont {
            return selectedFont
        }

        return typingAttributes[.font] as? NSFont ?? Self.defaultBodyFont
    }

    private func font(_ font: NSFont, applying traits: NSFontTraitMask) -> NSFont {
        var styledFont = font
        if traits.contains(.boldFontMask) {
            styledFont = NSFontManager.shared.convert(styledFont, toHaveTrait: .boldFontMask)
        }
        if traits.contains(.italicFontMask) {
            styledFont = NSFontManager.shared.convert(styledFont, toHaveTrait: .italicFontMask)
        }
        return styledFont
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
