// Copyright 2021 Jean Bovet
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

struct TurnoutEditListView: View {
    
    @ObservedObject var layout: Layout
    @State private var selection: Identifier<Turnout>? = nil

    var body: some View {
        VStack {
            Table(selection: $selection) {
                
                TableColumn("Name") { train in
                    TextField("Name", text: train.name)
                        .labelsHidden()
                }
                
                TableColumn("Protocol") { turnout in
                    Picker("Protocol", selection: turnout.addressProtocol) {
                        ForEach(CommandTurnoutProtocol.allCases, id:\.self) { proto in
                            Text(proto.rawValue)
                        }
                    }.labelsHidden()
                }
                
                TableColumn("Type") { turnout in
                    Picker("Type:", selection: turnout.category) {
                        ForEach(Turnout.Category.allCases, id:\.self) { type in
                            Text(type.description)
                        }
                    }.labelsHidden()
                }
                
                TableColumn("Address") { turnout in
                    HStack {
                        if turnout.wrappedValue.doubleAddress {
                            TextField("Address 1", value: turnout.addressValue,
                                      format: .number)
                            Text("|")
                            TextField("Address 2", value: turnout.address2Value,
                                      format: .number)
                        }
                        else {
                            TextField("Address", value: turnout.addressValue,
                                      format: .number)
                        }
                    }
                }
                
                TableColumn("State") { turnout in
                    Picker("State:", selection: turnout.state) {
                        ForEach(turnout.wrappedValue.allStates, id:\.self) { state in
                            Text(state.description)
                        }
                    }.labelsHidden()
                }
            } rows: {
                ForEach($layout.turnouts) { turnout in
                    TableRow(turnout)
                }
            }
            HStack {
                Text("\(layout.turnouts.count) turnouts")
                
                Spacer()
                
                Button("+") {
                    layout.newTurnout(name: "New Turnout", type: .singleLeft)
                }
                Button("-") {
                    layout.remove(turnoutID: selection!)
                }.disabled(selection == nil)
                
                Spacer().fixedSpace()
                
                Button("􀄬") {
                    layout.sortTurnouts()
                }
            }.padding()
        }
    }
}

extension Turnout {
    
    var addressProtocol: CommandTurnoutProtocol {
        get {
            return address.protocol
        }
        set {
            address = .init(address.address, newValue)
            // Also change the protocol of address 2 but keep its value
            address2 = .init(address2.address, newValue)
        }
    }
    
    var addressValue: Int {
        get {
            return Int(address.address)
        }
        set {
            address = .init(UInt32(newValue), addressProtocol)
        }
    }
    
    var address2Value: Int {
        get {
            return Int(address2.address)
        }
        set {
            address2 = .init(UInt32(newValue), addressProtocol)
        }
    }

}

struct TurnoutEditListView_Previews: PreviewProvider {

    static var previews: some View {
        TurnoutEditListView(layout: LayoutCCreator().newLayout())
    }
}
