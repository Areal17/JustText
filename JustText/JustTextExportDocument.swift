//
//  JustTextExportDocument.swift
//  JustText
//
//  Provides a single FileDocument type for all export formats.
//

import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat {
    case docx
    case pdf
    case markdown
    case plainText

    static let markdownContentType = UTType(
        importedAs: "net.daringfireball.markdown",
        conformingTo: .plainText
    )

    var contentType: UTType {
        switch self {
        case .docx:
            DOCXExportDocument.docxContentType
        case .pdf:
            .pdf
        case .markdown:
            Self.markdownContentType
        case .plainText:
            .plainText
        }
    }

    var defaultFilename: String {
        switch self {
        case .docx:
            "JustText.docx"
        case .pdf:
            "JustText.pdf"
        case .markdown:
            "JustText.md"
        case .plainText:
            "JustText.txt"
        }
    }
}

struct JustTextExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [
        DOCXExportDocument.docxContentType,
        .pdf,
        ExportFormat.markdownContentType,
        .plainText
    ]
    static let writableContentTypes: [UTType] = readableContentTypes

    nonisolated(unsafe) private var text: NSAttributedString
    private let format: ExportFormat

    init(text: NSAttributedString, format: ExportFormat) {
        self.text = text
        self.format = format
    }

    init(configuration: ReadConfiguration) throws {
        throw CocoaError(.fileReadUnsupportedScheme)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        switch format {
        case .docx:
            try FileWrapper(regularFileWithContents: DOCXWriter.documentData(from: text))
        case .pdf:
            try FileWrapper(regularFileWithContents: PDFWriter.pdfData(from: text))
        case .markdown:
            FileWrapper(regularFileWithContents: Data(MarkdownWriter.markdown(from: text).utf8))
        case .plainText:
            FileWrapper(regularFileWithContents: Data(text.string.utf8))
        }
    }
}
