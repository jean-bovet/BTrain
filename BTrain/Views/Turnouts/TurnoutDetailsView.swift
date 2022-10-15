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
    
    let doc: LayoutDocument
    
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
            
            SectionTitleView(label: "Speed Limits")

            TurnoutStateSpeedLimitView(turnout: turnout)
            
            SectionTitleView(label: "State")

            HStack {
                UndoProvider($turnout.requestedState) { state in
                    Picker("State:", selection: state) {
                        ForEach(turnout.allStates, id:\.self) { state in
                            Text(state.description)
                        }
                    }
                    .labelsHidden()
                }

                Spacer()

                Button("Set") {
                    doc.layoutController.sendTurnoutState(turnout: turnout) { _ in }
                }

                Button("Toggle") {
                    turnout.toggleToNextState()
                    doc.layoutController.sendTurnoutState(turnout: turnout) { _ in }
                }
            }
        }
    }
}

struct TurnoutStateSpeedLimitView: View {
    
    @ObservedObject var turnout: Turnout
    
    var body: some View {
        Form {
            ForEach(turnout.allStates, id: \.self) { state in
                let binding = Binding(
                    get: { turnout.stateSpeedLimit[state] ?? .unlimited },
                    set: { turnout.stateSpeedLimit[state] = $0 }
                )
                Picker("\(state.description):", selection: binding) {
                    ForEach(Turnout.SpeedLimit.allCases, id:\.self) { speedLimit in
                        Text(speedLimit.rawValue).tag(speedLimit as Turnout.SpeedLimit)
                    }
                }
                .fixedSize()
            }
        }
    }
}

extension Turnout {
    
    var addressProtocol: CommandTurnoutProtocol? {
        get {
            address.protocol
        }
        set {
            address = .init(address.address, newValue)
            // Also change the protocol of address 2 but keep its value
            address2 = .init(address2.address, newValue)
        }
    }
    
    var addressValue: Int {
        get {
            Int(address.address)
        }
        set {
            address = .init(UInt32(newValue), addressProtocol)
        }
    }
    
    var address2Value: Int {
        get {
            Int(address2.address)
        }
        set {
            address2 = .init(UInt32(newValue), addressProtocol)
        }
    }

}

struct TurnoutDetailsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: Layout())
    
    static var previews: some View {
        TurnoutDetailsView(doc: doc, layout: doc.layout, turnout: Turnout())
    }
}
