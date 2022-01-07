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

struct ImportLayoutSheet: View {
    
    @ObservedObject var document: LayoutDocument

    @Environment(\.presentationMode) var presentationMode

    @State private var selectedLayoutId = LayoutACreator.id

    var layout: Layout {
        return LayoutFactory.createLayout(selectedLayoutId)
    }
    
    var switchboard: SwitchBoard {
        return SwitchBoardFactory.generateSwitchboard(layout: layout)
    }
    
    var coordinator: LayoutCoordinator {
        return LayoutCoordinator(layout: layout, interface: nil)
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker("Choose Layout to Import", selection: $selectedLayoutId) {
                    ForEach(LayoutFactory.GlobalLayoutIDs, id:\.self) { layout in
                        Text(LayoutFactory.globalLayoutName(layout)).tag(layout)
                    }
                }.frame(maxWidth: 300)
            }.padding()

            ScrollView {
                SwitchBoardView(switchboard: switchboard, state: switchboard.state, layout: layout, coordinator: coordinator)
                    .fixedSize()
            }.frame(width: 800, height: 400)
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)
                
                Button("Import") {
                    document.layout.apply(other: LayoutFactory.createLayout(selectedLayoutId))
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct NewLayoutSheet_Previews: PreviewProvider {
    static var previews: some View {
        ImportLayoutSheet(document: LayoutDocument(layout: Layout()))
    }
}
