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

struct TurnoutDetailsView: View {
    
    @ObservedObject var layout: Layout

    @ObservedObject var turnout: Turnout
    
    var body: some View {
        VStack(alignment: .leading) {
            Form {
                UndoProvider($turnout.addressProtocol) { addressProtocol in
                    Picker("Protocol:", selection: addressProtocol) {
                        ForEach(CommandTurnoutProtocol.allCases, id:\.self) { proto in
                            Text(proto.rawValue).tag(proto as CommandTurnoutProtocol?)
                        }
                    }
                    .fixedSize()
                }
                
                UndoProvider($turnout.category) { category in
                    Picker("Type:", selection: category) {
                        ForEach(Turnout.Category.allCases, id:\.self) { type in
                            Text(type.description)
                        }
                    }
                    .fixedSize()
                }
            }
            
            SectionTitleView(label: "Address")
            
            Form {
                if turnout.doubleAddress {
                    UndoProvider($turnout.addressValue) { addressValue in
                        TextField("1:", value: addressValue,
                                  format: .number)
                    }
                    UndoProvider($turnout.address2Value) { address2Value in
                        TextField("2:", value: address2Value,
                                  format: .number)
                    }
                }
                else {
                    UndoProvider($turnout.addressValue) { addressValue in
                        TextField("1:", value: addressValue,
                                  format: .number)
                    }
                }
            }
            
            SectionTitleView(label: "Geometry")

            Form {
                UndoProvider($turnout.length) { length in
                    TextField("Length:", value: length, format: .number)
                        .unitStyle("cm")
                }
            }
            
            SectionTitleView(label: "State")

            HStack {
                UndoProvider($turnout.state) { state in
                    Picker("State:", selection: state) {
                        ForEach(turnout.allStates, id:\.self) { state in
                            Text(state.description)
                        }
                    }
                    .labelsHidden()
                }

                Spacer()

                Button("Set") {
                    layout.executor.sendTurnoutState(turnout: turnout) { }
                }
                
                Button("Toggle") {
                    turnout.toggleToNextState()
                    layout.executor.sendTurnoutState(turnout: turnout) { }
                }
            }
        }
    }
}

extension Turnout {
    
    var addressProtocol: CommandTurnoutProtocol? {
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

struct TurnoutDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        TurnoutDetailsView(layout: Layout(), turnout: Turnout(type: .doubleSlip, address: .init(0, nil)))
    }
}
