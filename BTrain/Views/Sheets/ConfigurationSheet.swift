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

struct ConfigurationSheet<Content: View>: View {
    @Environment(\.presentationMode) var presentationMode

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var header: some View {
        HStack {
            Text(title)
                .font(.title)
                .foregroundColor(.black)
            Spacer()
        }
        .padding()
        .background(.yellow)
    }

    var footer: some View {
        VStack(spacing: 0) {
            Divider()

            HStack {
                Spacer()

                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }.padding()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            content

            footer
                .padding([.top])
        }
    }
}

struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConfigurationSheet(title: "This is the title") {
                Text("This is the content")
                    .padding()
            }
        }.preferredColorScheme(.dark)
        Group {
            ConfigurationSheet(title: "This is the title") {
                Text("This is the content")
                    .padding()
            }
        }.preferredColorScheme(.light)
    }
}
