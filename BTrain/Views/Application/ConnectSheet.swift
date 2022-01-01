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

struct ConnectSheet: View {
    
    @ObservedObject var document: LayoutDocument

    @Environment(\.presentationMode) var presentationMode
    
    enum ConnectionType {
        case centralStation
        case simulator
    }
    
    @State private var type = ConnectionType.centralStation
    
    @State private var address = "192.168.86.47"
    @State private var port = "15731"

    @State private var msg = ""

    var body: some View {
        VStack(alignment: .leading) {
            Form {
                Picker("Connect To:", selection: $type) {
                    Text("Central Station").tag(ConnectionType.centralStation)
                    Text("Simulator (offline)").tag(ConnectionType.simulator)
                }

                Group {
                    TextField("Address:", text: $address)
                        .frame(minWidth: 250)
                    
                    TextField("Port:", text: $port)
                        .frame(minWidth: 200)
                }.disabled(type == .simulator)
                                
                if !msg.isEmpty {
                    Text("\(msg)")
                        .padding()
                }
            }

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)

                Spacer()
                
                Button("Connect") {
                    if type == .centralStation {
                        document.connect(address: address, port: UInt16(port)!) { error in
                            if let error = error {
                                msg = error.localizedDescription
                            } else {
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                    } else {
                        document.connectToSimulator() { error in
                            if let error = error {
                                msg = error.localizedDescription
                            } else {
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }.keyboardShortcut(.defaultAction)                
            }.padding()
        }
    }    
}

struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectSheet(document: LayoutDocument(layout: Layout()))
    }
}
