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

struct TrainListView: View {
    
    @Environment(\.undoManager) var undoManager
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Train>? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                Table(selection: $selection) {
                    TableColumn("Enabled") { train in
                        UndoProvider(train.enabled) { enabled in
                            Toggle("Enabled", isOn: enabled)
                                .labelsHidden()
                        }
                    }.width(80)
                    
                    TableColumn("Icon") { train in
                        if let image = document.locomotiveIconManager.icon(for: train.wrappedValue.locomotive?.id) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 25)
                        }
                    }.width(80)

                    TableColumn("Name") { train in
                        TextField("Name", text: train.name)
                            .labelsHidden()
                    }
                } rows: {
                    ForEach($layout.trains) { train in
                        TableRow(train)
                    }
                }
                
                HStack {
                    Text("\(layout.trains.count) trains")
                    
                    Spacer()
                    
                    Button("+") {
                        let train = layout.newTrain()
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.trains.removeAll { t in
                                t.id == train.id
                            }
                        })
                    }
                    Button("-") {
                        let train = layout.train(for: selection!)!
                        document.layoutController.delete(train: train)
                        
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.addTrain(train)
                        })
                    }.disabled(selection == nil)
                    
                    Spacer().fixedSpace()
                    
                    Button("􀄬") {
                        layout.sortTrains()
                    }
                }.padding()
            }.frame(maxWidth: SideListFixedWidth)

            if let selection = selection, let train = layout.train(for: selection) {
                ScrollView {
                    TrainDetailsView(document: document, train: train)
                        .padding()
                }
            } else {
                CenteredLabelView(label: "No Selected Train")
            }
        }.onAppear {
            if selection == nil {
                selection = layout.trains.first?.id
            }
        }
    }
}

struct TrainListView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    
    static var previews: some View {
        TrainListView(document: doc, layout: doc.layout)
    }
}
