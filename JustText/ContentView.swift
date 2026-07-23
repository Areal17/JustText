//
//  ContentView.swift
//  JustText
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: JustTextDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(JustTextDocument()))
}
