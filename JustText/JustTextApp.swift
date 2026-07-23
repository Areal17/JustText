//
//  JustTextApp.swift
//  JustText
//
//  Created by Ingo Wiederoder on 23.07.26.
//

import SwiftUI

@main
struct JustTextApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: JustTextDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
