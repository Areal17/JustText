//
//  ContentView.swift
//  JustText
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Binding var document: JustTextDocument
    /// URL of the opened document; `nil` while the document is unsaved.
    var fileURL: URL? = nil

    /// Controls whether the trailing inspector is visible.
    @State private var isInspectorPresented = false
    @State private var isExportingDocument = false
    @State private var exportFormat: ExportFormat = .docx
    @State private var isSearchPresented = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var isReplaceExpanded = false
    @State private var currentMatchIndex = 0
    @State private var pendingReplace: ReplaceCommand? = nil
    @State private var isFocusMode = false
    @State private var isHoveringExitButton = false
    @AppStorage(FormatToolbarSettings.isVisibleKey) private var isFormatToolbarVisible = false
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isReplaceFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isSearchPresented {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Button {
                            isReplaceExpanded.toggle()
                        } label: {
                            Image(systemName: isReplaceExpanded ? "chevron.down" : "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Ersetzen ein-/ausblenden")

                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Suchen", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .focused($isSearchFieldFocused)
                            .onSubmit { navigateToNext() }

                        if !searchText.isEmpty {
                            Text(matchSummary)
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            navigateToPrevious()
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(searchText.isEmpty)
                        .keyboardShortcut("g", modifiers: [.command, .shift])
                        .help("Vorheriges Ergebnis (⇧⌘G)")

                        Button {
                            navigateToNext()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(searchText.isEmpty)
                        .keyboardShortcut("g", modifiers: [.command])
                        .help("Nächstes Ergebnis (⌘G)")

                        Button {
                            closeSearch()
                        } label: {
                            Label("Suche schließen", systemImage: "xmark.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Suche schließen")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    if isReplaceExpanded {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.arrow.right")
                                .foregroundStyle(.secondary)

                            TextField("Ersetzen", text: $replaceText)
                                .textFieldStyle(.roundedBorder)
                                .focused($isReplaceFieldFocused)

                            Button("Ersetzen") { replaceNext() }
                                .disabled(searchText.isEmpty)

                            Button("Alle ersetzen") { replaceAll() }
                                .disabled(searchText.isEmpty)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                }
                .onAppear {
                    isSearchFieldFocused = true
                }
                .onExitCommand { closeSearch() }
                .onChange(of: searchText) {
                    currentMatchIndex = 0
                }

                Divider()
            }

            TextEditView(
                text: $document.text,
                searchText: searchText,
                currentMatchIndex: currentMatchIndex,
                pendingReplace: $pendingReplace
            )

            if isFormatToolbarVisible && !isFocusMode {
                Divider()
                FormatToolbarView()
            }
        }
            .overlay(alignment: .topTrailing) {
                if isFocusMode {
                    Button { toggleFocusMode() } label: {
                        Image(systemName: "xmark.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .opacity(isHoveringExitButton ? 1.0 : 0.25)
                    .onHover { isHoveringExitButton = $0 }
                    .padding(12)
                    .help("Fokus-Modus beenden (⌘⇧F)")
                }
            }
            .background {
                // Keyboard shortcut works even when toolbar is hidden.
                Button("") { toggleFocusMode() }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .hidden()
            }
            .toolbar(isFocusMode ? .hidden : .automatic, for: .windowToolbar)
            .inspector(isPresented: $isInspectorPresented) {
                InspectorView(text: document.text.string)
                    .inspectorColumnWidth(min: 220, ideal: 260, max: 360)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: showSearch) {
                        Label("Suchen", systemImage: "magnifyingglass")
                    }
                    .keyboardShortcut("f", modifiers: [.command])
                    .help("Suchen")
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Als DOCX exportieren") { startExport(.docx) }
                        Button("Als PDF exportieren") { startExport(.pdf) }
                        Button("Als Markdown exportieren") { startExport(.markdown) }
                        Button("Als Text exportieren") { startExport(.plainText) }
                    } label: {
                        Label("Exportieren", systemImage: "square.and.arrow.up")
                    }
                    .help("Dokument exportieren")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.trailing")
                    }
                    .help("Inspector ein-/ausblenden")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isFormatToolbarVisible.toggle()
                    } label: {
                        Label("Formatierungsleiste", systemImage: "textformat")
                    }
                    .help("Formatierungsleiste ein-/ausblenden")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button { toggleFocusMode() } label: {
                        Label("Fokus-Modus", systemImage: "text.justify")
                    }
                    .help("Fokus-Modus (⌘⇧F)")
                }
            }
            .fileExporter(
                isPresented: $isExportingDocument,
                document: JustTextExportDocument(text: document.text, format: exportFormat),
                contentType: exportFormat.contentType,
                defaultFilename: exportFormat.defaultFilename(for: fileURL)
            ) { _ in }
    }

    private func startExport(_ format: ExportFormat) {
        exportFormat = format
        isExportingDocument = true
    }

    private func toggleFocusMode() {
        isFocusMode.toggle()
        if isFocusMode {
            isInspectorPresented = false
        }
    }

    private func showSearch() {
        isSearchPresented = true
        isSearchFieldFocused = true
    }

    private func closeSearch() {
        searchText = ""
        replaceText = ""
        isSearchPresented = false
        isSearchFieldFocused = false
        isReplaceExpanded = false
        currentMatchIndex = 0
    }

    private var matchCount: Int {
        SearchMatchFinder.ranges(of: searchText, in: document.text.string).count
    }

    /// "3 von 12" for the current match, or a hint when nothing was found.
    private var matchSummary: String {
        let count = matchCount
        guard count > 0 else { return String(localized: "Keine Treffer") }
        return String(localized: "\(min(currentMatchIndex, count - 1) + 1) von \(count)")
    }

    private func navigateToNext() {
        let count = matchCount
        guard count > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % count
    }

    private func navigateToPrevious() {
        let count = matchCount
        guard count > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + count) % count
    }

    private func replaceNext() {
        let ranges = SearchMatchFinder.ranges(of: searchText, in: document.text.string)
        guard !ranges.isEmpty else { return }
        pendingReplace = .current(query: searchText, replacement: replaceText, matchIndex: currentMatchIndex)
        // Nach dem Ersetzen rückt der nächste Treffer auf denselben Index vor —
        // außer beim letzten Treffer, dann zurück auf 0.
        if currentMatchIndex >= ranges.count - 1 {
            currentMatchIndex = 0
        }
    }

    private func replaceAll() {
        pendingReplace = .all(query: searchText, replacement: replaceText)
        currentMatchIndex = 0
    }
}

#Preview {
    ContentView(document: .constant(JustTextDocument()))
}
