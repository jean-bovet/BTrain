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

    @State private var errorString: String?
    
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
                    do {
                        guard let file = Bundle.main.url(forResource: "Predefined", withExtension: "btrain") else {
                            throw CocoaError(.fileNoSuchFile)
                        }

                        let fw = try FileWrapper(url: file, options: [])
                        document.layout.apply(other: try fw.layout())
                        document.trainIconManager.setIcons(try fw.icons())
                    } catch {
                        errorString = error.localizedDescription
                    }
                    hideWelcomeScreen = true
                }
            }
            if let errorString = errorString {
                Spacer()
                Text(errorString)
                    .foregroundColor(.red)
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
