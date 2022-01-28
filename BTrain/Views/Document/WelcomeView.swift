// Copyright 2021-22 Jean Bovet
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

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
                        document.apply(try fw.layout())
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
