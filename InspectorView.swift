//
//  InspectorView.swift
//  JustText
//
//  The trailing inspector panel showing document statistics.
//

import SwiftUI

/// A simple inspector that summarizes the current document.
struct InspectorView: View {
    let text: String

    private var characterCount: Int {
        text.count
    }

    private var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private var lineCount: Int {
        text.isEmpty ? 0 : text.split(separator: "\n", omittingEmptySubsequences: false).count
    }

//    private var paragraphCount: Int {
//        text.split(separator: "\n").filter { line in
//            !line.allSatisfy { $0.isWhitespace }
//        }.count
//    }

    var body: some View {
        Form {
            Section("Statistik") {
                LabeledContent("Zeichen", value: "\(characterCount)")
                LabeledContent("Wörter", value: "\(wordCount)")
                LabeledContent("Zeilen", value: "\(lineCount)")
//                LabeledContent("Absätze", value: "\(paragraphCount)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Inspector")
    }
}

#Preview {
    InspectorView(text: "Hello, world!\nZweite Zeile.")
        .frame(width: 260)
}
