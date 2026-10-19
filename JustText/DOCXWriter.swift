//
//  DOCXWriter.swift
//  JustText
//
//  Creates a minimal WordprocessingML document package.
//

import AppKit
import Foundation

enum DOCXWriter {
    static func documentData(from attributedString: NSAttributedString) throws -> Data {
        let documentXML = documentXML(from: attributedString)
        let archive = ZIPArchive()

        archive.addFile(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8))
        archive.addFile(path: "_rels/.rels", data: Data(packageRelationshipsXML.utf8))
        archive.addFile(path: "word/document.xml", data: Data(documentXML.utf8))
        archive.addFile(path: "word/_rels/document.xml.rels", data: Data(documentRelationshipsXML.utf8))

        return archive.data()
    }

    private static func documentXML(from attributedString: NSAttributedString) -> String {
        let paragraphs = AttributedParagraphs.paragraphs(of: attributedString)
        let body = paragraphs.map { paragraph in
            paragraphXML(paragraph)
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>\(body)<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1417" w:right="1417" w:bottom="1417" w:left="1417" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>
        """
    }

    private static func paragraphXML(_ paragraph: NSAttributedString) -> String {
        let paragraphStyle = paragraph.length > 0
            ? paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            : nil
        let paragraphProperties = paragraphPropertiesXML(for: paragraphStyle)
        let runs = runXML(from: paragraph)

        return "<w:p>\(paragraphProperties)\(runs)</w:p>"
    }

    private static func paragraphPropertiesXML(for paragraphStyle: NSParagraphStyle?) -> String {
        guard let paragraphStyle else { return "" }

        var properties: [String] = []
        if paragraphStyle.firstLineHeadIndent > 0 || paragraphStyle.headIndent > 0 {
            properties.append(#"<w:ind w:left="\#(twips(from: paragraphStyle.headIndent))" w:firstLine="\#(twips(from: paragraphStyle.firstLineHeadIndent))"/>"#)
        }

        if paragraphStyle.paragraphSpacing > 0 {
            properties.append(#"<w:spacing w:after="\#(twips(from: paragraphStyle.paragraphSpacing))"/>"#)
        }

        guard !properties.isEmpty else { return "" }
        return "<w:pPr>\(properties.joined())</w:pPr>"
    }

    private static func runXML(from attributedString: NSAttributedString) -> String {
        guard attributedString.length > 0 else { return "" }

        var xml = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttributes(in: fullRange) { attributes, range, _ in
            let text = attributedString.attributedSubstring(from: range).string
            guard !text.isEmpty else { return }

            let runProperties = runPropertiesXML(from: attributes)
            xml += "<w:r>\(runProperties)\(textXML(from: text))</w:r>"
        }
        return xml
    }

    private static func runPropertiesXML(from attributes: [NSAttributedString.Key: Any]) -> String {
        var properties: [String] = []

        if let font = attributes[.font] as? NSFont {
            let familyName = font.familyName ?? font.fontName
            properties.append(#"<w:rFonts w:ascii="\#(xmlEscaped(familyName))" w:hAnsi="\#(xmlEscaped(familyName))" w:cs="\#(xmlEscaped(familyName))"/>"#)

            let traits = NSFontManager.shared.traits(of: font)
            if traits.contains(.boldFontMask) {
                properties.append("<w:b/>")
            }
            if traits.contains(.italicFontMask) {
                properties.append("<w:i/>")
            }
            properties.append(#"<w:sz w:val="\#(Int((font.pointSize * 2).rounded()))"/>"#)
        }

        if attributes[.underlineStyle] != nil {
            properties.append(#"<w:u w:val="single"/>"#)
        }

        guard !properties.isEmpty else { return "" }
        return "<w:rPr>\(properties.joined())</w:rPr>"
    }

    private static func textXML(from text: String) -> String {
        var xml = ""
        var textBuffer = ""

        func flushTextBuffer() {
            guard !textBuffer.isEmpty else { return }
            xml += #"<w:t xml:space="preserve">\#(xmlEscaped(textBuffer))</w:t>"#
            textBuffer = ""
        }

        for character in text {
            if character == "\t" {
                flushTextBuffer()
                xml += "<w:tab/>"
            } else {
                textBuffer.append(character)
            }
        }

        flushTextBuffer()
        return xml
    }

    private static func twips(from points: CGFloat) -> Int {
        Int((points * 20).rounded())
    }

    private static func xmlEscaped(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
    """

    private static let packageRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
    """

    private static let documentRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
    """
}

private final class ZIPArchive {
    private struct Entry {
        let path: String
        let data: Data
        let crc32: UInt32
        let localHeaderOffset: UInt32
    }

    private var output = Data()
    private var entries: [Entry] = []

    func addFile(path: String, data: Data) {
        let pathData = Data(path.utf8)
        let crc32 = CRC32.checksum(data)
        let offset = UInt32(output.count)

        output.appendLittleEndian(UInt32(0x04034b50))
        output.appendLittleEndian(UInt16(20))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(crc32)
        output.appendLittleEndian(UInt32(data.count))
        output.appendLittleEndian(UInt32(data.count))
        output.appendLittleEndian(UInt16(pathData.count))
        output.appendLittleEndian(UInt16(0))
        output.append(pathData)
        output.append(data)

        entries.append(Entry(path: path, data: data, crc32: crc32, localHeaderOffset: offset))
    }

    func data() -> Data {
        let centralDirectoryOffset = UInt32(output.count)

        for entry in entries {
            let pathData = Data(entry.path.utf8)

            output.appendLittleEndian(UInt32(0x02014b50))
            output.appendLittleEndian(UInt16(20))
            output.appendLittleEndian(UInt16(20))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(entry.crc32)
            output.appendLittleEndian(UInt32(entry.data.count))
            output.appendLittleEndian(UInt32(entry.data.count))
            output.appendLittleEndian(UInt16(pathData.count))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt16(0))
            output.appendLittleEndian(UInt32(0))
            output.appendLittleEndian(entry.localHeaderOffset)
            output.append(pathData)
        }

        let centralDirectorySize = UInt32(output.count) - centralDirectoryOffset

        output.appendLittleEndian(UInt32(0x06054b50))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(0))
        output.appendLittleEndian(UInt16(entries.count))
        output.appendLittleEndian(UInt16(entries.count))
        output.appendLittleEndian(centralDirectorySize)
        output.appendLittleEndian(centralDirectoryOffset)
        output.appendLittleEndian(UInt16(0))

        return output
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { byte in
        var crc = UInt32(byte)
        for _ in 0..<8 {
            crc = crc & 1 == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
