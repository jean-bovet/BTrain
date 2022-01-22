//
//  AppView.swift
//  BTrain
//
//  Created by Jean Bovet on 1/21/22.
//

import SwiftUI

struct AppView: View {
    
    @ObservedObject var document: LayoutDocument

    @AppStorage("hideWelcomeScreen") var hideWelcomeScreen = false

    var body: some View {
        if hideWelcomeScreen {
            ContentView(document: document)
        } else {
            WelcomeView(document: document)
        }
    }
}

struct AppView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: Layout())
    
    static var previews: some View {
        AppView(document: doc)
    }
}
