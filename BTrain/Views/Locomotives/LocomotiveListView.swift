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

struct LocomotiveListView: View {
    
    @Environment(\.undoManager) var undoManager
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Locomotive>? = nil

    var body: some View {
        HStack(alignment: .top) {
            VStack {
                Table(selection: $selection) {
                    TableColumn("Enabled") { loc in
                        UndoProvider(loc.enabled) { enabled in
                            Toggle("Enabled", isOn: enabled)
                                .labelsHidden()
                        }
                    }.width(80)
                    
                    TableColumn("Icon") { loc in
                        if let image = document.locomotiveIconManager.icon(for: loc.wrappedValue.id) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 25)
                        }
                    }.width(80)

                    TableColumn("Name") { loc in
                        TextField("Name", text: loc.name)
                            .labelsHidden()
                    }
                } rows: {
                    ForEach($layout.locomotives) { locomotive in
                        TableRow(locomotive)
                    }
                }
                
                HStack {
                    Text("\(layout.locomotives.count) locomotives")
                    
                    Spacer()
                    
                    Button("+") {
                        let loc = layout.newLocomotive()
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.locomotives.removeAll { t in
                                t.id == loc.id
                            }
                        })
                    }
                    Button("-") {
                        let loc = layout.locomotive(for: selection!)!
                        layout.delete(locId: loc.id)
                        
                        undoManager?.registerUndo(withTarget: layout, handler: { layout in
                            layout.addLocomotive(loc)
                        })
                    }.disabled(selection == nil)
                    
                    Spacer().fixedSpace()
                    
                    Button("􀈄") {
                        document.discoverLocomotiveConfirmation.toggle()
                    }
                    .disabled(!document.connected)
                    .help("Download Locomotives")

                    Spacer().fixedSpace()
                    
                    Button("􀄬") {
                        layout.sortLocomotives()
                    }
                }.padding([.leading])
            }.frame(maxWidth: SideListFixedWidth)

            if let selection = selection, let loc = layout.locomotive(for: selection) {
                ScrollView {
                    LocomotiveDetailsView(document: document, loc: loc)
                        .padding()
                }
            } else {
                CenteredLabelView(label: "No Selected Locomotive")
            }
        }.onAppear {
            if selection == nil {
                selection = layout.locomotives.first?.id
            }
        }
    }
}

struct LocomotiveListView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    
    static var previews: some View {
        ConfigurationSheet(title: "Locomotives") {
            LocomotiveListView(document: doc, layout: doc.layout)
        }
    }
}
