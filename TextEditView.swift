//
//  TextEditView.swift
//  JustText
//
//  A rich-text editing view backed by TextKit 2.
//

import SwiftUI
import AppKit

enum ReplaceCommand {
    case current(query: String, replacement: String, matchIndex: Int)
    case all(query: String, replacement: String)
}

/// A SwiftUI wrapper around a `FormattingTextView` (an `NSTextView` subclass)
/// configured to use TextKit 2.
///
/// The text view is created with `usingTextLayoutManager: true`, which opts the
/// text system into the TextKit 2 object graph (`NSTextLayoutManager`,
/// `NSTextContentStorage`, …) rather than the legacy `NSLayoutManager`.
struct TextEditView: NSViewRepresentable {
    @Binding var text: NSAttributedString
    let searchText: String
    let currentMatchIndex: Int
    @Binding var pendingReplace: ReplaceCommand?

    init(
        text: Binding<NSAttributedString>,
        searchText: String = "",
        currentMatchIndex: Int = 0,
        pendingReplace: Binding<ReplaceCommand?> = .constant(nil)
    ) {
        _text = text
        self.searchText = searchText
        self.currentMatchIndex = currentMatchIndex
        _pendingReplace = pendingReplace
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Create the text view opted into TextKit 2.
        let textView = FormattingTextView(usingTextLayoutManager: true)
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Let the text view grow vertically while wrapping horizontally.
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        textView.textStorage?.setAttributedString(text)

        // Embed the text view in a scroll view.
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? FormattingTextView,
              let textStorage = textView.textStorage else { return }

        // Only push the binding value into the text view when it actually
        // differs, otherwise editing would reset the insertion point.
        if !textStorage.isEqual(to: text) {
            textView.clearSearchHighlights()
            textStorage.setAttributedString(text)
        }

        textView.updateSearchHighlights(query: searchText, currentMatchIndex: currentMatchIndex)

        if let command = pendingReplace {
            textView.execute(replaceCommand: command)
            pendingReplace = nil
        }
    }

    /// Bridges `NSTextView` edits back into the SwiftUI binding.
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let text: Binding<NSAttributedString>

        init(text: Binding<NSAttributedString>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text.wrappedValue = textView.attributedString()
        }
    }
}
