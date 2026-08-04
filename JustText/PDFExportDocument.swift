//
//  PDFExportDocument.swift
//  JustText
//
//  Wraps the current JustText document in a write-only FileDocument for PDF export.
//

import SwiftUI
import UniformTypeIdentifiers

struct PDFExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.pdf]
    static let writableContentTypes: [UTType] = [.pdf]

    nonisolated(unsafe) private var text: NSAttributedString

    init(text: NSAttributedString) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(regularFileWithContents: PDFWriter.pdfData(from: text))
    }
}
