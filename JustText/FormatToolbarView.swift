//
//  FormatToolbarView.swift
//  JustText
//
//  A bottom bar with icon buttons for text formatting.
//

import SwiftUI
import AppKit

/// Key under which the visibility of the format toolbar is persisted.
enum FormatToolbarSettings {
    static let isVisibleKey = "isFormatToolbarVisible"
}

/// A formatting bar shown at the bottom of the editor window.
///
/// Each button sends its action down the responder chain (`to: nil`), exactly
/// like the "Format" menu, so it targets the `FormattingTextView` that is
/// currently first responder.
struct FormatToolbarView: View {
    var body: some View {
        HStack(spacing: 4) {
            Menu {
                Button("Titel") { send(#selector(FormattingTextView.applyTitleStyle(_:))) }
                Button("Überschrift") { send(#selector(FormattingTextView.applyHeadingStyle(_:))) }
                Button("Unterüberschrift") { send(#selector(FormattingTextView.applySubheadingStyle(_:))) }
                Button("Text") { send(#selector(FormattingTextView.applyBodyStyle(_:))) }
                Button("Proportional") { send(#selector(FormattingTextView.applyProportionalStyle(_:))) }
            } label: {
                Label("Stil", systemImage: "textformat.size")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Absatzstil")

            Divider().frame(height: 16)

            formatButton("Fett", systemImage: "bold", action: #selector(FormattingTextView.applyBoldStyle(_:)))
            formatButton("Kursiv", systemImage: "italic", action: #selector(FormattingTextView.applyItalicStyle(_:)))
            formatButton("Schrift auswählen ...", systemImage: "textformat", action: #selector(FormattingTextView.showFontPanel(_:)))

            Divider().frame(height: 16)

            formatButton("Aufzählungsliste", systemImage: "list.bullet", action: #selector(FormattingTextView.applyBulletList(_:)))
            formatButton("Spiegelstrichliste", systemImage: "list.dash", action: #selector(FormattingTextView.applyDashList(_:)))
            formatButton("Nummerierte Liste", systemImage: "list.number", action: #selector(FormattingTextView.applyNumberedList(_:)))
            formatButton("Checkliste", systemImage: "checklist", action: #selector(FormattingTextView.applyChecklist(_:)))
            formatButton("Zitatblock", systemImage: "text.quote", action: #selector(FormattingTextView.applyQuoteBlock(_:)))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func formatButton(_ title: LocalizedStringKey, systemImage: String, action: Selector) -> some View {
        Button { send(action) } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 24, height: 20)
        }
        .buttonStyle(.borderless)
        // Keep keyboard focus (and the selection) in the text view.
        .focusable(false)
        .help(title)
    }

    private func send(_ selector: Selector) {
        NSApp.sendAction(selector, to: nil, from: nil)
    }
}

#Preview {
    FormatToolbarView()
}
