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
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isSearchPresented {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Suchen", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .focused($isSearchFieldFocused)

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
                .onAppear {
                    isSearchFieldFocused = true
                }

                Divider()
            }

            TextEditView(text: $document.text, searchText: searchText)
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
        isSearchPresented = false
        isSearchFieldFocused = false
    }
}

#Preview {
    ContentView(document: .constant(JustTextDocument()))
}
