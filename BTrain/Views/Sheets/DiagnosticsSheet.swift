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

// This view displays to the user the list of errors, if any, for the current layout
struct DiagnosticsSheet: View {
    let layout: Layout
    let options: LayoutDiagnostic.Options

    @Environment(\.presentationMode) var presentationMode

    struct DisplayError: Identifiable, Hashable {
        let id = UUID().uuidString
        let error: String
    }

    var errors: [DisplayError] {
        do {
            let diag = LayoutDiagnostic(layout: layout)
            let errors = try diag.check(options)
            return errors.map { DisplayError(error: $0.localizedDescription) }
        } catch {
            return [DisplayError(error: error.localizedDescription)]
        }
    }

    var body: some View {
        VStack {
            if errors.isEmpty {
                Text("The layout is correct!")
                    .padding()
            } else {
                Table(of: DisplayError.self) {
                    TableColumn("Error") { error in
                        Text("\(error.error)")
                    }
                } rows: {
                    ForEach(errors) { error in
                        TableRow(error)
                    }
                }.frame(width: 800, height: 600)

                Divider()
            }

            Button("OK") {
                self.presentationMode.wrappedValue.dismiss()
            }.keyboardShortcut(.defaultAction)
        }
    }
}

struct DiagnosticsSheet_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        DiagnosticsSheet(layout: doc.layout, options: .all)
    }
}
