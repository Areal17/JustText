//
//  JustTextApp.swift
//  JustText
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import SwiftUI
import AppKit

@main
struct JustTextApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: JustTextDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            EditCommands()
            FormatCommands()
        }
    }
}

/// Erweitert das "Bearbeiten"-Menü um "Mit Formatierung kopieren".
/// ⌘C kopiert nun standardmäßig OHNE Formatierung.
/// ⇧⌘C kopiert MIT Formatierung.
struct EditCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Mit Formatierung kopieren") {
                NSApp.sendAction(#selector(FormattingTextView.copyWithFormatting(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: [.shift, .command])
        }
    }
}

/// The "Format" menu. Each item sends its action down the responder chain
/// (`to: nil`), so it targets whichever `FormattingTextView` is first responder.
struct FormatCommands: Commands {
    var body: some Commands {
        CommandMenu("Format") {
            Button("Titel") { send(#selector(FormattingTextView.applyTitleStyle(_:))) }
                .keyboardShortcut("t", modifiers: [.shift, .command])
            Button("Überschrift") { send(#selector(FormattingTextView.applyHeadingStyle(_:))) }
                .keyboardShortcut("h", modifiers: [.shift, .command])
            Button("Unterüberschrift") { send(#selector(FormattingTextView.applySubheadingStyle(_:))) }
                .keyboardShortcut("j", modifiers: [.shift, .command])
            Button("Text") { send(#selector(FormattingTextView.applyBodyStyle(_:))) }
                .keyboardShortcut("b", modifiers: [.shift, .command])
            Button("Proportional") { send(#selector(FormattingTextView.applyProportionalStyle(_:))) }
                .keyboardShortcut("m", modifiers: [.shift, .command])

            Divider()

            Button("Fett") { send(#selector(FormattingTextView.applyBoldStyle(_:))) }
                .keyboardShortcut("b", modifiers: [.command])
            Button("Kursiv") { send(#selector(FormattingTextView.applyItalicStyle(_:))) }
                .keyboardShortcut("i", modifiers: [.command])
            Button("Fett und Kursiv") { send(#selector(FormattingTextView.applyBoldItalicStyle(_:))) }
                .keyboardShortcut("i", modifiers: [.shift, .command])
            Button("Schrift auswählen ...") { send(#selector(FormattingTextView.showFontPanel(_:))) }
                .keyboardShortcut("t", modifiers: [.command])

            Divider()

            Button("Aufzählungsliste") { send(#selector(FormattingTextView.applyBulletList(_:))) }
                .keyboardShortcut("7", modifiers: [.shift, .command])
            Button("Spiegelstrichliste") { send(#selector(FormattingTextView.applyDashList(_:))) }
                .keyboardShortcut("8", modifiers: [.shift, .command])
            Button("Nummerierte Liste") { send(#selector(FormattingTextView.applyNumberedList(_:))) }
                .keyboardShortcut("9", modifiers: [.shift, .command])
            Button("Zitatblock") { send(#selector(FormattingTextView.applyQuoteBlock(_:))) }
                .keyboardShortcut("'", modifiers: [.command])

            Divider()

            Button("Checkliste") { send(#selector(FormattingTextView.applyChecklist(_:))) }
                .keyboardShortcut("l", modifiers: [.shift, .command])
        }
    }

    private func send(_ selector: Selector) {
        NSApp.sendAction(selector, to: nil, from: nil)
    }
}
