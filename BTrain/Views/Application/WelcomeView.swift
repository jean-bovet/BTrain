//
//  WelcomeView.swift
//  BTrain
//
//  Created by Jean Bovet on 1/21/22.
//

import SwiftUI

struct WelcomeView: View {
    
    @ObservedObject var document: LayoutDocument

    @AppStorage("hideWelcomeScreen") var hideWelcomeScreen = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(nsImage: NSImage(named: "AppIcon")!)
                Spacer()
                VStack(alignment: .leading) {
                    Text("Welcome to BTrain!")
                        .font(.largeTitle)
                    Text("A free open-source model railway management software")
                        .font(.caption)
                }
                Spacer()
            }
            Spacer()
            Divider()
            Spacer()
            HStack {
                Button("􀈷 New Document") {
                    hideWelcomeScreen = true
                }
                Spacer().fixedSpace()
                Button("􀉚 Use Predefined Layout") {
                    hideWelcomeScreen = true
                }
            }
            Spacer()
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(document: LayoutDocument(layout: Layout()))
    }
}
