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

    private var statistics: TextStatistics {
        TextStatistics(text: text)
    }

    var body: some View {
        let statistics = statistics

        Form {
            Section("Statistik") {
                LabeledContent("Zeichen", value: "\(statistics.characterCount)")
                LabeledContent("Zeichen ohne Leerzeichen", value: "\(statistics.characterCountWithoutWhitespace)")
                LabeledContent("Wörter", value: "\(statistics.wordCount)")
                LabeledContent("Zeilen", value: "\(statistics.lineCount)")
                LabeledContent("Absätze", value: "\(statistics.paragraphCount)")
                LabeledContent("Sätze", value: "\(statistics.sentenceCount)")
                LabeledContent("Lesezeit", value: timeDescription(for: statistics.readingTimeMinutes))
                LabeledContent("Sprechzeit", value: timeDescription(for: statistics.speakingTimeMinutes))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Inspector")
    }

    private func timeDescription(for minutes: Int) -> String {
        if minutes == 1 {
            "1 Min."
        } else {
            "\(minutes) Min."
        }
    }
}

#Preview {
    InspectorView(text: "Hello, world!\nZweite Zeile.")
        .frame(width: 260)
}
