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

extension LayoutElementsEditingView where More == EmptyView {
    
    init(layout: Layout,
         new: @escaping () -> E,
         delete: @escaping (E) -> Void,
         sort: @escaping CompletionBlock,
         elementContainer: Binding<LayoutElementContainer<E>>,
         @ViewBuilder row: @escaping RowViewBuilder,
         @ViewBuilder editor: @escaping (E) -> Editor) {
        self.init(layout: layout, new: new, delete: delete, sort: sort, elementContainer: elementContainer, more: { EmptyView() }, row: row, editor: editor)
    }

}

struct LayoutElementsEditingView<E: LayoutElement, More: View, Row: View, Editor: View>: View {
    
    typealias RowViewBuilder = (Binding<E>) -> Row
    typealias MoreViewBuilder = () -> More

    let new: () -> E
    let delete: (E) -> Void
    let sort: CompletionBlock
    let more: MoreViewBuilder
    let row: RowViewBuilder
    let editor: (E) -> Editor
        
    init(layout: Layout,
         new: @escaping () -> E,
         delete: @escaping (E) -> Void,
         sort: @escaping CompletionBlock,
         elementContainer: Binding<LayoutElementContainer<E>>,
         @ViewBuilder more: @escaping MoreViewBuilder,
         @ViewBuilder row: @escaping RowViewBuilder,
         @ViewBuilder editor: @escaping (E) -> Editor) {
        self.layout = layout
        self.new = new
        self.delete = delete
        self.sort = sort
        self.more = more
        self.row = row
        self.editor = editor
        _elementContainer = elementContainer
    }

    
    @ObservedObject var layout: Layout
    @Binding var elementContainer: LayoutElementContainer<E>
    
    @State private var selection: Identifier<E.ItemType>?

    @Environment(\.undoManager) var undoManager

    var statusLabel: String {
        let count = elementContainer.elements.count
        switch count {
        case 0:
            return "No Element"
        case 1:
            return "One Element"
        default:
            return "\(count) Elements"
        }
    }
        
    struct ListOfElements: View {
        
        let row: RowViewBuilder

        @Binding var selection: Identifier<E.ItemType>?
        @Binding var elements: [E]
        
        var body: some View {
            List(selection: $selection) {
                ForEach($elements) { element in
                    row(element)
                }
            }.listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
    
    var scriptList: some View {
        VStack(alignment: .leading) {
            ListOfElements(row: row, selection: $selection, elements: $elementContainer.elements)
            
            HStack {
                Text(statusLabel)
                    .fixedSize()
                
                Spacer().fixedSpace()

                Button("+") {
                    let element = elementContainer.add(new())
                    selection = element.id
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        delete(element)
                    })
                }
                Button("-") {
                    let script = elementContainer[selection]!
                    delete(script)
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
                    sort()
                }
                
                if let view = more(), !(view is EmptyView) {
                    Spacer().fixedSpace()
                    view
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
                .fixedSize(horizontal: true, vertical: false)
            Divider()
            if let element = elementContainer[selection] {
                editor(element)
            } else {
                CenteredLabelView(label: "No Selected Element")
            }
        }
    }
}
