//
//  PDFWriter.swift
//  JustText
//
//  Renders an NSAttributedString into a paginated A4 PDF using CoreText.
//

import AppKit
import CoreText

struct PDFWriter {
    static let pageWidth: CGFloat = 595.28   // A4 in points
    static let pageHeight: CGFloat = 841.89  // A4 in points
    static let margin: CGFloat = 72          // 1 inch

    static func pdfData(from attributedString: NSAttributedString) throws -> Data {
        let contentWidth = pageWidth - 2 * margin
        let contentHeight = pageHeight - 2 * margin

        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var offset: CFIndex = 0
        let totalLength = attributedString.length

        repeat {
            context.beginPage(mediaBox: &mediaBox)

            let contentRect = CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight)
            let path = CGPath(rect: contentRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            CTFrameDraw(frame, context)

            let drawn = CTFrameGetVisibleStringRange(frame)
            offset = drawn.location + drawn.length

            context.endPage()
        } while offset < totalLength

        context.closePDF()
        return pdfData as Data
    }
}
