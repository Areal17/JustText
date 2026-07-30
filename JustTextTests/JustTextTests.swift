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
