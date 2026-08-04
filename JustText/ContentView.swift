//
//  ContentView.swift
//  JustText
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: JustTextDocument

    /// Controls whether the trailing inspector is visible.
    @State private var isInspectorPresented = false
    @State private var isExportingDOCX = false
    @State private var isSearchPresented = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var isReplaceExpanded = false
    @State private var currentMatchIndex = 0
    @State private var pendingReplace: ReplaceCommand? = nil
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

                        Button {
                            navigateToPrevious()
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(searchText.isEmpty)
                        .help("Vorheriges Ergebnis")

                        Button {
                            navigateToNext()
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(searchText.isEmpty)
                        .help("Nächstes Ergebnis")

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
        }
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
                    Button {
                        isExportingDOCX = true
                    } label: {
                        Label("Als DOCX exportieren", systemImage: "square.and.arrow.up")
                    }
                    .help("Als DOCX exportieren")
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.trailing")
                    }
                    .help("Inspector ein-/ausblenden")
                }
            }
            .fileExporter(
                isPresented: $isExportingDOCX,
                document: DOCXExportDocument(text: document.text),
                contentType: DOCXExportDocument.docxContentType,
                defaultFilename: "JustText.docx"
            ) { _ in }
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

    private func navigateToNext() {
        let count = SearchMatchFinder.ranges(of: searchText, in: document.text.string).count
        guard count > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % count
    }

    private func navigateToPrevious() {
        let count = SearchMatchFinder.ranges(of: searchText, in: document.text.string).count
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
