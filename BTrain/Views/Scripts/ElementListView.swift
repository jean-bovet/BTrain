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

// TODO: move to a proper location in the project
struct ElementListView<E: LayoutElement<E> & ObservableObject, Editor: View>: View {
    
    let content: (E) -> Editor
    
    init(layout: Layout, elementContainer: Binding<LayoutElementContainer<E>>, @ViewBuilder content: @escaping (E) -> Editor) {
        self.layout = layout
        self.content = content
        _elementContainer = elementContainer
    }

    @ObservedObject var layout: Layout
    @Binding var elementContainer: LayoutElementContainer<E>
    
    @State private var selection: Identifier<E.ItemType>?

    @Environment(\.undoManager) var undoManager

    // TODO: refactor into a single container for many other elements?
    var statusLabel: String {
        let count = elementContainer.elements.count
        switch count {
        case 0:
            return "No Script"
        case 1:
            return "One Script"
        default:
            return "\(count) Scripts"
        }
    }
    
    struct ElementNameView: View {

        @ObservedObject var element: E
        
        var body: some View {
            Text(element.name)
        }

    }
    
    struct ListOfElements: View {
        
        @Binding var selection: Identifier<E.ItemType>?
        @Binding var elements: [E]
        
        var body: some View {
            List(selection: $selection) {
                ForEach(elements) { element in
                    ElementNameView(element: element)
                }
            }
        }
    }
    
    var scriptList: some View {
        VStack(alignment: .leading) {
            ListOfElements(selection: $selection, elements: $elementContainer.elements)
            
            HStack {
                Text(statusLabel)
                
                Spacer()
                
                Button("+") {
                    let element = elementContainer.add(E())
                    selection = element.id
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        elementContainer.remove(element.id)
                    })
                }
                Button("-") {
                    let script = elementContainer[selection]!
                    elementContainer.remove(script.id)
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        elementContainer.add(script)
                    })
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()

                Button("􀐅") {
                    if let selection = selection {
                        elementContainer.duplicate(selection)
                    }
                }.disabled(selection == nil)

                Spacer().fixedSpace()
                
                Button("􀄬") {
                    elementContainer.sort()
                }
            }.padding([.leading])
        }
        .onAppear {
            if selection == nil {
                selection = elementContainer.elements.first?.id
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top) {
            scriptList
                .frame(maxWidth: SideListFixedWidth)
            if let element = elementContainer[selection] {
                content(element)
            } else {
                CenteredLabelView(label: "No Selected Script")
            }
        }
    }
}
