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

    var body: some View {
        TextEditView(text: $document.text)
            .inspector(isPresented: $isInspectorPresented) {
                InspectorView(text: document.text.string)
                    .inspectorColumnWidth(min: 220, ideal: 260, max: 360)
            }
            .toolbar {
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
}

#Preview {
    ContentView(document: .constant(JustTextDocument()))
}
