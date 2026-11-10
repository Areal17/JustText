//
//  JustTextTests.swift
//  JustTextTests
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import AppKit
import XCTest
@testable import JustText

final class JustTextTests: XCTestCase {

    func testDOCXExportCreatesWordPackage() throws {
        let data = try DOCXWriter.documentData(from: NSAttributedString(string: "Hello"))

        XCTAssertEqual(data.prefix(4), Data([0x50, 0x4b, 0x03, 0x04]))
        XCTAssertTrue(String(data: data, encoding: .isoLatin1)?.contains("word/document.xml") == true)
        XCTAssertTrue(String(data: data, encoding: .isoLatin1)?.contains("[Content_Types].xml") == true)
    }

    func testDOCXExportEscapesDocumentText() throws {
        let data = try DOCXWriter.documentData(from: NSAttributedString(string: "A < B & C"))
        let archiveText = String(data: data, encoding: .isoLatin1)

        XCTAssertTrue(archiveText?.contains("A &lt; B &amp; C") == true)
    }

    func testDOCXExportIncludesFontFamily() throws {
        let font = NSFont(name: "Helvetica", size: 13) ?? NSFont.systemFont(ofSize: 13)
        let text = NSAttributedString(string: "Font", attributes: [.font: font])
        let data = try DOCXWriter.documentData(from: text)
        let archiveText = String(data: data, encoding: .isoLatin1)
        let familyName = font.familyName ?? font.fontName

        XCTAssertTrue(archiveText?.contains(#"w:ascii="\#(familyName)""#) == true)
    }

    func testMarkdownExportConvertsHeadings() {
        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "Titel\n", attributes: [.font: NSFont.systemFont(ofSize: 28, weight: .bold)]))
        text.append(NSAttributedString(string: "Kapitel\n", attributes: [.font: NSFont.systemFont(ofSize: 20, weight: .bold)]))
        text.append(NSAttributedString(string: "Abschnitt", attributes: [.font: NSFont.systemFont(ofSize: 15, weight: .semibold)]))

        XCTAssertEqual(MarkdownWriter.markdown(from: text), "# Titel\n\n## Kapitel\n\n### Abschnitt\n")
    }

    func testMarkdownExportConvertsListsWithoutBlankLines() {
        let text = NSAttributedString(string: "•\tA\n–\tB\n1.\tC\n☐\tD\n☑\tE")

        XCTAssertEqual(MarkdownWriter.markdown(from: text), "- A\n- B\n1. C\n- [ ] D\n- [x] E\n")
    }

    func testMarkdownExportConvertsQuotes() {
        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = 24
        style.headIndent = 24
        let text = NSMutableAttributedString(string: "Davor\n")
        text.append(NSAttributedString(string: "Zitat eins\nZitat zwei", attributes: [.paragraphStyle: style]))

        XCTAssertEqual(MarkdownWriter.markdown(from: text), "Davor\n\n> Zitat eins\n> Zitat zwei\n")
    }

    func testMarkdownExportConvertsEmphasis() throws {
        let regular = try XCTUnwrap(NSFont(name: "Helvetica", size: 13))
        let bold = NSFontManager.shared.convert(regular, toHaveTrait: .boldFontMask)
        let italic = NSFontManager.shared.convert(regular, toHaveTrait: .italicFontMask)
        let boldItalic = NSFontManager.shared.convert(bold, toHaveTrait: .italicFontMask)

        let text = NSMutableAttributedString()
        text.append(NSAttributedString(string: "Ein ", attributes: [.font: regular]))
        text.append(NSAttributedString(string: "fettes ", attributes: [.font: bold]))
        text.append(NSAttributedString(string: "und ", attributes: [.font: regular]))
        text.append(NSAttributedString(string: "kursives", attributes: [.font: italic]))
        text.append(NSAttributedString(string: " und ", attributes: [.font: regular]))
        text.append(NSAttributedString(string: "beides", attributes: [.font: boldItalic]))

        XCTAssertEqual(MarkdownWriter.markdown(from: text), "Ein **fettes** und *kursives* und ***beides***\n")
    }

    func testMarkdownExportEscapesMarkdownSyntax() {
        let text = NSAttributedString(string: "a*b_c\n# kein Titel\n1. kein Listenpunkt")

        XCTAssertEqual(
            MarkdownWriter.markdown(from: text),
            "a\\*b\\_c\n\n\\# kein Titel\n\n1\\. kein Listenpunkt\n"
        )
    }

    func testMarkdownExportCollapsesEmptyParagraphs() {
        let text = NSAttributedString(string: "A\n\n\n  \nB\n")

        XCTAssertEqual(MarkdownWriter.markdown(from: text), "A\n\nB\n")
    }

    func testMarkdownExportOfEmptyDocumentIsEmpty() {
        XCTAssertEqual(MarkdownWriter.markdown(from: NSAttributedString(string: "")), "")
    }

    func testSearchMatchFinderFindsCaseInsensitiveMatches() {
        let ranges = SearchMatchFinder.ranges(of: "text", in: "Text und text")

        XCTAssertEqual(ranges, [
            NSRange(location: 0, length: 4),
            NSRange(location: 9, length: 4)
        ])
    }

    func testSearchMatchFinderIgnoresWhitespaceOnlyQueries() {
        XCTAssertTrue(SearchMatchFinder.ranges(of: "   ", in: "Text").isEmpty)
    }

    func testTextStatisticsCountsDocumentStructure() {
        let statistics = TextStatistics(text: "Hallo Welt!\n\nDas ist ein Test.")

        XCTAssertEqual(statistics.characterCountWithoutWhitespace, 24)
        XCTAssertEqual(statistics.wordCount, 6)
        XCTAssertEqual(statistics.lineCount, 3)
        XCTAssertEqual(statistics.paragraphCount, 2)
        XCTAssertEqual(statistics.sentenceCount, 2)
        XCTAssertEqual(statistics.readingTimeMinutes, 1)
        XCTAssertEqual(statistics.speakingTimeMinutes, 1)
    }

    // MARK: - Editor

    /// A text view inside a window, so that it has an undo manager.
    @MainActor
    private func makeEditor(_ string: String) -> FormattingTextView {
        let textView = FormattingTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        textView.isRichText = true
        textView.allowsUndo = true
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: string, attributes: FormattingTextView.defaultTypingAttributes)
        )

        let window = NSWindow(
            contentRect: textView.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.contentView = textView
        return textView
    }

    @MainActor
    func testCheckboxTogglesOnMarker() {
        let editor = makeEditor("☐\tMilch\n☐\tBrot")

        XCTAssertTrue(editor.toggleCheckbox(atCharacterIndex: 0))
        XCTAssertEqual(editor.string, "☑\tMilch\n☐\tBrot")

        // The position right after the box of the second item also counts.
        XCTAssertTrue(editor.toggleCheckbox(atCharacterIndex: 9))
        XCTAssertEqual(editor.string, "☑\tMilch\n☑\tBrot")

        XCTAssertTrue(editor.toggleCheckbox(atCharacterIndex: 0))
        XCTAssertEqual(editor.string, "☐\tMilch\n☑\tBrot")
    }

    @MainActor
    func testCheckboxIgnoresClicksOutsideMarker() {
        let editor = makeEditor("☐\tMilch\n•\tBrot\nText")

        XCTAssertFalse(editor.toggleCheckbox(atCharacterIndex: 4))   // inside "Milch"
        XCTAssertFalse(editor.toggleCheckbox(atCharacterIndex: 8))   // bullet item
        XCTAssertFalse(editor.toggleCheckbox(atCharacterIndex: 15))  // plain paragraph
        XCTAssertFalse(editor.toggleCheckbox(atCharacterIndex: 19))  // end of document
        XCTAssertEqual(editor.string, "☐\tMilch\n•\tBrot\nText")
    }

    @MainActor
    func testBoldTogglesOnAndOff() throws {
        let editor = makeEditor("Hallo Welt")
        let range = NSRange(location: 0, length: 5)
        editor.setSelectedRange(range)

        editor.applyBoldStyle(nil)
        XCTAssertTrue(try isBold(editor, at: 0))
        XCTAssertFalse(try isBold(editor, at: 7))

        editor.setSelectedRange(range)
        editor.applyBoldStyle(nil)
        XCTAssertFalse(try isBold(editor, at: 0))
    }

    @MainActor
    func testBoldOnMixedSelectionMakesEverythingBold() throws {
        let editor = makeEditor("Hallo Welt")
        editor.setSelectedRange(NSRange(location: 0, length: 5))
        editor.applyBoldStyle(nil)

        editor.setSelectedRange(NSRange(location: 0, length: 10))
        editor.applyBoldStyle(nil)

        XCTAssertTrue(try isBold(editor, at: 0))
        XCTAssertTrue(try isBold(editor, at: 7))
    }

    @MainActor
    private func isBold(_ editor: FormattingTextView, at index: Int) throws -> Bool {
        let font = try XCTUnwrap(editor.textStorage?.attribute(.font, at: index, effectiveRange: nil) as? NSFont)
        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
    }

    @MainActor
    func testReplaceAllIsUndoableInOneStep() throws {
        let editor = makeEditor("eins zwei eins drei eins")

        editor.execute(replaceCommand: .all(query: "eins", replacement: "1"))
        XCTAssertEqual(editor.string, "1 zwei 1 drei 1")

        let undoManager = try XCTUnwrap(editor.undoManager)
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()
        XCTAssertEqual(editor.string, "eins zwei eins drei eins")
    }

    func testPDFExportProducesPDF() throws {
        let data = try PDFWriter.pdfData(from: NSAttributedString(string: "Hallo"))

        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "%PDF")
    }

    func testTextStatisticsHandlesEmptyText() {
        let statistics = TextStatistics(text: "")

        XCTAssertEqual(statistics.characterCount, 0)
        XCTAssertEqual(statistics.characterCountWithoutWhitespace, 0)
        XCTAssertEqual(statistics.wordCount, 0)
        XCTAssertEqual(statistics.lineCount, 0)
        XCTAssertEqual(statistics.paragraphCount, 0)
        XCTAssertEqual(statistics.sentenceCount, 0)
        XCTAssertEqual(statistics.readingTimeMinutes, 0)
        XCTAssertEqual(statistics.speakingTimeMinutes, 0)
    }
}
