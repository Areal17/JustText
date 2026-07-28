//
//  JustTextDocument.swift
//  JustText
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct JustTextDocument: FileDocument {
    // NSAttributedString is a non-Sendable reference type, but FileDocument
    // requires Sendable conformance. The document is only used as an immutable
    // snapshot when reading/writing, so this access is safe.
    nonisolated(unsafe) var text: NSAttributedString

    init(text: NSAttributedString = NSAttributedString(string: "")) {
        self.text = text
    }

    static let readableContentTypes = [
        UTType(exportedAs: "com.example.jute-text")
    ]

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Files are stored as RTF, but fall back to plain UTF-8 text so that
        // existing plain files can still be opened.
        if let attributed = NSAttributedString(rtf: data, documentAttributes: nil) {
            text = attributed
        } else if let string = String(data: data, encoding: .utf8) {
            text = NSAttributedString(string: string)
        } else {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let range = NSRange(location: 0, length: text.length)
        let data = try text.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
        return .init(regularFileWithContents: data)
    }
}
