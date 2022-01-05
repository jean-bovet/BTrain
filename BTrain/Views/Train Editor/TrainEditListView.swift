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

struct TrainEditListView: View {
    
    @Environment(\.undoManager) var undoManager
    
    @ObservedObject var layout: Layout
    
    @State private var selection: Identifier<Train>? = nil

    var body: some View {
        VStack {
            Table(selection: $selection) {                
                TableColumn("Enabled") { train in
                    Toggle("Enabled", isOn: train.enabled)
                        .labelsHidden()
                }.width(80)

                TableColumn("Name") { train in
                    TextField("Name", text: train.name)
                        .labelsHidden()
                }
                
                TableColumn("Decoder Type") { train in
                    Picker("Decoder", selection: train.addressDecoderType) {
                        ForEach(DecoderType.allCases, id:\.self) { proto in
                            Text(proto.rawValue)
                        }
                    }.labelsHidden()
                }
                
                TableColumn("Address") { train in
                    TextField("Address", value: train.addressValue,
                              format: .number)
                        .labelsHidden()
                }
            } rows: {
                ForEach($layout.mutableTrains) { train in
                    TableRow(train)
                }
            }
            
            HStack {
                Text("\(layout.trains.count) trains")
                
                Spacer()
                
                Button("+") {
                    let train = layout.newTrain()
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.mutableTrains.removeAll { t in
                            return t.id == train.id
                        }
                    })
                }
                Button("-") {
                    let train = layout.mutableTrain(for: selection!)
                    layout.remove(trainId: selection!)
                    
                    undoManager?.registerUndo(withTarget: layout, handler: { layout in
                        layout.mutableTrains.append(train!)
                    })
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()
                
                Button("􀄬") {
                    layout.sortTrains()
                }
            }.padding()
        }
    }
}

extension Train {
    
    var addressDecoderType: DecoderType? {
        get {
            return address.decoderType
        }
        set {
            address = .init(address.address, newValue)
        }
    }
    
    var addressValue: Int {
        get {
            return Int(address.address)
        }
        set {
            address = .init(UInt32(newValue), addressDecoderType)
        }
    }
}

struct TrainEditListView_Previews: PreviewProvider {
    
    static var previews: some View {
        TrainEditListView(layout: LayoutCCreator().newLayout())
    }
}
