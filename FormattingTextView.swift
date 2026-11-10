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
    private var searchHighlightRanges: [NSRange] = []
    private var searchHighlightTextRanges: [NSTextRange] = []

    /// The query/match the view last scrolled to. Highlights are refreshed on
    /// every edit, but scrolling must only happen when the target changes —
    /// otherwise typing with the search bar open jumps back to the match.
    private var lastScrollTarget: SearchScrollTarget?

    private struct SearchScrollTarget: Equatable {
        let query: String
        let matchIndex: Int
    }

    // MARK: - Default ("normal") text style

    /// The font used for normal body text (matches the editor default).
    static let defaultBodyFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    /// The typing attributes for normal, unformatted text.
    static let defaultTypingAttributes: [NSAttributedString.Key: Any] = [
        .font: defaultBodyFont,
        .paragraphStyle: NSParagraphStyle.default
    ]

    func updateSearchHighlights(query: String, currentMatchIndex: Int = 0) {
        clearSearchHighlights()

        let ranges = SearchMatchFinder.ranges(of: query, in: string)
        guard !ranges.isEmpty else {
            lastScrollTarget = nil
            return
        }

        searchHighlightRanges = ranges
        let normalColor = NSColor.systemYellow.withAlphaComponent(0.45)
        let currentColor = NSColor.systemBlue.withAlphaComponent(0.35)

        for (i, range) in ranges.enumerated() {
            let color = i == currentMatchIndex ? currentColor : normalColor
            layoutManager?.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
            if let textRange = textRange(for: range) {
                searchHighlightTextRanges.append(textRange)
                textLayoutManager?.addRenderingAttribute(.backgroundColor, value: color, for: textRange)
            }
        }

        let safeIndex = min(currentMatchIndex, ranges.count - 1)
        let target = SearchScrollTarget(query: query, matchIndex: safeIndex)
        if target != lastScrollTarget {
            lastScrollTarget = target
            scrollRangeToVisible(ranges[safeIndex])
        }
    }

    func execute(replaceCommand: ReplaceCommand) {
        // After replacing, the next match moves up to the same index — scroll to it.
        lastScrollTarget = nil

        switch replaceCommand {
        case .current(let query, let replacement, let index):
            replaceMatch(at: index, query: query, replacement: replacement)
        case .all(let query, let replacement):
            replaceAllMatches(query: query, replacement: replacement)
        }
    }

    private func replaceMatch(at index: Int, query: String, replacement: String) {
        let ranges = SearchMatchFinder.ranges(of: query, in: string)
        guard !ranges.isEmpty else { return }
        let range = ranges[index % ranges.count]
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
    }

    private func replaceAllMatches(query: String, replacement: String) {
        let ranges = SearchMatchFinder.ranges(of: query, in: string)
        guard !ranges.isEmpty else { return }
        // Registers all replacements as a single undoable edit.
        guard shouldChangeText(
            inRanges: ranges.map { NSValue(range: $0) },
            replacementStrings: Array(repeating: replacement, count: ranges.count)
        ) else { return }
        textStorage?.beginEditing()
        for range in ranges.reversed() {
            textStorage?.replaceCharacters(in: range, with: replacement)
        }
        textStorage?.endEditing()
        didChangeText()
    }

    func clearSearchHighlights() {
        for range in searchHighlightRanges {
            layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        }
        for textRange in searchHighlightTextRanges {
            textLayoutManager?.removeRenderingAttribute(.backgroundColor, for: textRange)
        }
        searchHighlightRanges = []
        searchHighlightTextRanges = []
    }

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
        if let match = AttributedParagraphs.listMarkerRegex.firstMatch(
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

    // MARK: - Checklist toggling

    /// A click on a checklist marker checks or unchecks the item.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 1, toggleCheckbox(atCharacterIndex: characterIndexForInsertion(at: point)) {
            return
        }
        super.mouseDown(with: event)
    }

    /// Toggles the checkbox of the paragraph containing `index`, provided the
    /// index lies on the marker itself. Returns whether a checkbox was toggled.
    ///
    /// Insertion indexes round to the nearest character boundary, so both the
    /// paragraph start and the position right after the box count as a hit.
    @discardableResult
    func toggleCheckbox(atCharacterIndex index: Int) -> Bool {
        guard let textStorage, index >= 0, index <= textStorage.length else { return false }

        let string = textStorage.string as NSString
        let paragraphStart = string.paragraphRange(for: NSRange(location: index, length: 0)).location
        guard index <= paragraphStart + 1,
              paragraphStart + 2 <= string.length,
              string.substring(with: NSRange(location: paragraphStart + 1, length: 1)) == "\t" else {
            return false
        }

        let markerRange = NSRange(location: paragraphStart, length: 1)
        let toggled: String
        switch string.substring(with: markerRange) {
        case "☐": toggled = "☑"
        case "☑": toggled = "☐"
        default: return false
        }

        guard shouldChangeText(in: markerRange, replacementString: toggled) else { return false }
        textStorage.replaceCharacters(in: markerRange, with: toggled)
        didChangeText()
        return true
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

    /// Toggles the traits: if the whole selection already has them they are
    /// removed, otherwise they are added.
    private func applyInlineFontTraits(_ traits: NSFontTraitMask) {
        let remove = selectionHasFontTraits(traits)
        applyFontConversion { font($0, traits: traits, remove: remove) }
    }

    private func selectionHasFontTraits(_ traits: NSFontTraitMask) -> Bool {
        let range = selectedRange()
        guard range.length > 0, let textStorage else {
            let font = typingAttributes[.font] as? NSFont ?? Self.defaultBodyFont
            return NSFontManager.shared.traits(of: font).contains(traits)
        }

        var hasTraits = true
        textStorage.enumerateAttribute(.font, in: range) { value, _, stop in
            let font = value as? NSFont ?? Self.defaultBodyFont
            if !NSFontManager.shared.traits(of: font).contains(traits) {
                hasTraits = false
                stop.pointee = true
            }
        }
        return hasTraits
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

    private func font(_ font: NSFont, traits: NSFontTraitMask, remove: Bool) -> NSFont {
        let fontManager = NSFontManager.shared
        var styledFont = font
        for trait in [NSFontTraitMask.boldFontMask, .italicFontMask] where traits.contains(trait) {
            styledFont = remove
                ? fontManager.convert(styledFont, toNotHaveTrait: trait)
                : fontManager.convert(styledFont, toHaveTrait: trait)
        }
        return styledFont
    }

    private func textRange(for range: NSRange) -> NSTextRange? {
        guard let contentStorage = textLayoutManager?.textContentManager as? NSTextContentStorage,
              let startLocation = contentStorage.location(contentStorage.documentRange.location, offsetBy: range.location),
              let endLocation = contentStorage.location(startLocation, offsetBy: range.length) else {
            return nil
        }

        return NSTextRange(location: startLocation, end: endLocation)
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

    private func stripLeadingMarker(_ line: NSMutableAttributedString) {
        let range = NSRange(location: 0, length: line.length)
        if let match = AttributedParagraphs.listMarkerRegex.firstMatch(in: line.string, options: .anchored, range: range) {
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
