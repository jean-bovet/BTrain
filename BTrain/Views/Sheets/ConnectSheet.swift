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

struct ConnectSheet: View {
    @ObservedObject var document: LayoutDocument
    @ObservedObject var onConnectTasks: LayoutOnConnectTasks

    @Environment(\.presentationMode) var presentationMode

    enum ConnectionType {
        case centralStation
        case simulator
    }

    @State private var type = ConnectionType.centralStation

    // Used to activate all the turnouts when connecting to the Digital Controller
    // in order to ensure that all turnouts are physically matching the layout model.
    @AppStorage("activateTurnouts") private var activateTurnouts = true

    @AppStorage("digitalControllerAddress") private var address = "192.168.86.24"
    @AppStorage("digitalControllerPort") private var port = "15731"

    @State private var msg = ""

    @State private var connecting = false

    func didConnect(simulator: Bool, withError error: Error?) {
        if let error = error {
            connecting.toggle()
            msg = error.localizedDescription
        } else {
            onConnectTasks.performOnConnectTasks(simulator: simulator, activateTurnouts: activateTurnouts) {
                connecting.toggle()
                self.presentationMode.wrappedValue.dismiss()
            }
        }
    }

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

                Toggle("Activate Turnouts", isOn: $activateTurnouts)

                VStack(alignment: .leading) {
                    if let percentage = onConnectTasks.connectionCompletionPercentage {
                        ProgressView(value: percentage)
                    } else {
                        ProgressView(value: 0).hidden()
                    }
                    if let label = onConnectTasks.connectionCompletionLabel {
                        Text(label)
                            .font(.footnote)
                    }
                }
            }.disabled(connecting)

            HStack {
                if !msg.isEmpty {
                    Text("\(msg)")
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding()
                }
            }

            HStack {
                Button("Cancel") {
                    onConnectTasks.cancel = true
                    document.simulator.stop {}
                    document.interface.disconnect {}
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)

                Spacer()

                Button("Connect") {
                    connecting.toggle()
                    if type == .centralStation {
                        document.connect(address: address, port: UInt16(port)!) { error in
                            didConnect(simulator: false, withError: error)
                        }
                    } else {
                        document.connectToSimulator(enable: false) { error in
                            didConnect(simulator: true, withError: error)
                        }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(connecting)
            }.padding()
        }.onAppear {
            msg = ""
            onConnectTasks.connectionCompletionPercentage = nil
            onConnectTasks.connectionCompletionLabel = nil
        }
    }
}

struct ConnectView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: Layout())

    static var previews: some View {
        ConnectSheet(document: doc, onConnectTasks: doc.onConnectTasks)
    }
}
