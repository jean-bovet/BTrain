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

struct CS3SendMessageView: View {
    enum CS3Command {
        case setDirection
        case queryDirection
        case speed
    }

    let doc: LayoutDocument

    @State private var selection: CS3Command = .queryDirection
    @State private var cs3Command: Command? = nil

    @State private var priority: UInt8 = 0
    @State private var command: UInt8 = 0
    @State private var resp: UInt8 = 0
    @State private var hash: UInt16 = 0
    @State private var dlc: UInt8 = 0
    @State private var byte0: UInt8 = 0
    @State private var byte1: UInt8 = 0
    @State private var byte2: UInt8 = 0
    @State private var byte3: UInt8 = 0
    @State private var byte4: UInt8 = 0
    @State private var byte5: UInt8 = 0
    @State private var byte6: UInt8 = 0
    @State private var byte7: UInt8 = 0

    var body: some View {
        VStack {
            HStack {
                Picker("Command:", selection: $selection) {
                    Text("Set Direction").tag(CS3Command.setDirection)
                    Text("Query Direction").tag(CS3Command.queryDirection)
                    Text("Speed").tag(CS3Command.speed)
                }

                switch selection {
                case .setDirection:
                    CS3CommandDirectionView(doc: doc, query: false, command: $cs3Command)

                case .queryDirection:
                    CS3CommandDirectionView(doc: doc, query: true, command: $cs3Command)

                case .speed:
                    CS3CommandSpeedView(doc: doc, command: $cs3Command)
                }
            }

            Divider()

            Form {
                TextField("Prio:", value: $priority, format: .number).unitStyle(priority.toHex())
                TextField("Command:", value: $command, format: .number).unitStyle(command.toHex())
                TextField("Resp:", value: $resp, format: .number).unitStyle(resp.toHex())
                TextField("Hash:", value: $hash, format: .number).unitStyle(hash.toHex())
                TextField("DLC:", value: $dlc, format: .number).unitStyle(dlc.toHex())

                GroupBox("Bytes") {
                    HStack {
                        TextField("0:", value: $byte0, format: .number).unitStyle(byte0.toHex())
                        TextField("1:", value: $byte1, format: .number).unitStyle(byte1.toHex())
                        TextField("2:", value: $byte2, format: .number).unitStyle(byte2.toHex())
                        TextField("3:", value: $byte3, format: .number).unitStyle(byte3.toHex())
                    }

                    HStack {
                        TextField("4:", value: $byte4, format: .number).unitStyle(byte4.toHex())
                        TextField("5:", value: $byte5, format: .number).unitStyle(byte5.toHex())
                        TextField("6:", value: $byte6, format: .number).unitStyle(byte6.toHex())
                        TextField("7:", value: $byte7, format: .number).unitStyle(byte7.toHex())
                    }
                }
            }

            Button("Send") {
                if let command = cs3Command {
                    doc.interface.execute(command: command, completion: nil)
                }
            }
        }.onChange(of: selection) { _ in
            updateFields()
        }.onAppear {
            updateFields()
        }
    }

    private func updateFields() {
        guard let command = cs3Command else {
            return
        }

        guard let (cm, _) = MarklinCANMessage.from(command: command) else {
            return
        }

        priority = cm.prio
        self.command = cm.command
        resp = cm.resp
        hash = cm.hash
        dlc = cm.dlc
        byte0 = cm.byte0
        byte1 = cm.byte1
        byte2 = cm.byte2
        byte3 = cm.byte3
        byte4 = cm.byte4
        byte5 = cm.byte5
        byte6 = cm.byte6
        byte7 = cm.byte7
    }
}

struct CS3SendMessageView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutComplex().newLayout())

    static var previews: some View {
        CS3SendMessageView(doc: doc)
    }
}
