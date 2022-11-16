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

struct NewTurnoutSheet: View {
    
    let layout: Layout
    let context = ShapeContext()
    
    @Environment(\.presentationMode) var presentationMode

    @State private var name = ""
    
    @State private var category = Turnout.Category.singleLeft
    
    var body: some View {
        VStack {
            Form {
                TextField("Name:", text: $name)
                Picker("Type:", selection: $category) {
                    ForEach(Turnout.Category.allCases, id:\.self) { category in
                        HStack {
                            Text(category.description)
                            Spacer()
                            HStack {
                                ForEach(Turnout.states(for: category)) { state in
                                    TurnoutShapeView(layout: layout, category: category, requestedState: state, actualState: state, shapeContext: context, reservation: false)
                                }
                            }
                        }
                    }
                }.pickerStyle(.inline)
                
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer().fixedSpace()
                
                Button("OK") {
                    layout.turnouts.add(layout.newTurnout(name: name, category: category))
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct NewTurnoutSheet_Previews: PreviewProvider {
    
    static var previews: some View {
        NewTurnoutSheet(layout: LayoutLoop2().newLayout())
    }
}
