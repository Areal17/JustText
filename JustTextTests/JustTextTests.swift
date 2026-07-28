//
//  JustTextTests.swift
//  JustTextTests
//
//  Created by Ingo Wiederoder on 23.07.26.
//

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
}
