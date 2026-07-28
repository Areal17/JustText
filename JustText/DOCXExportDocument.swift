//
//  DOCXExportDocument.swift
//  JustText
//
//  Wraps the current JustText document in a write-only FileDocument for export.
//

import SwiftUI
import UniformTypeIdentifiers

struct DOCXExportDocument: FileDocument {
    static let docxContentType = UTType(
        importedAs: "org.openxmlformats.wordprocessingml.document",
        conformingTo: .zip
    )

    static let readableContentTypes: [UTType] = [docxContentType]
    static let writableContentTypes: [UTType] = [docxContentType]

    nonisolated(unsafe) private var text: NSAttributedString

    init(text: NSAttributedString) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(regularFileWithContents: DOCXWriter.documentData(from: text))
    }
}
