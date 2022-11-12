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

struct CS3ReceivedMessageView: View {
    
    @ObservedObject var mi: MarklinInterface
    
    @State private var selectedMessage: MarklinCANMessage.ID? = nil

    @State private var showKnownMessages = true
    @State private var showUnknownMessages = true

    var messages: [MarklinCANMessage] {
        return mi.messages.filter { message in
            let knownMessage = MarklinInterface.isKnownMessage(msg: message)
            return showKnownMessages && knownMessage || showUnknownMessages && !knownMessage
        }
    }

    var body: some View {
        VStack {
            HStack {
                Toggle("Listen", isOn: $mi.collectMessages)
                Toggle("Show Know Messages", isOn: $showKnownMessages)
                Toggle("Show Unknown Messages", isOn: $showUnknownMessages)
                Spacer()
                Button("Clear") {
                    mi.messages.removeAll()
                }
            }
            Table(messages, selection: $selectedMessage) {
                TableColumn("Prio") { message in
                    Text("\(message.prio.toHex())")
                }.width(60)
                TableColumn("Command") { message in
                    Text("\(message.command.toHex())")
                }.width(60)
                TableColumn("Resp") { message in
                    Text("\(message.resp.toHex())")
                }.width(60)
                TableColumn("Hash") { message in
                    Text("\(message.hash.toHex())")
                }.width(60)
                TableColumn("DLC") { message in
                    Text("\(message.dlc.toHex())")
                }.width(60)
                TableColumn("Bytes 0 to 7") { message in
                    HStack {
                        Text("\(message.byte0.toHex())")
                        Text("\(message.byte1.toHex())")
                        Text("\(message.byte2.toHex())")
                        Text("\(message.byte3.toHex())")
                        Text("\(message.byte4.toHex())")
                        Text("\(message.byte5.toHex())")
                        Text("\(message.byte6.toHex())")
                        Text("\(message.byte7.toHex())")
                    }
                }
                TableColumn("Description") { message in
                    if let description = MarklinCANMessagePrinter.description(message: message) {
                        Text(description)
                    } else {
                        Text("?")
                    }
                }
            }
        }
    }
}

extension MarklinCANMessage: Identifiable {
    
    var id: Data {
        data
    }
    
    
}

struct CS3ReceivedMessageView_Previews: PreviewProvider {
    
    static let doc: LayoutDocument = {
        let doc = LayoutDocument(layout: LayoutComplex().newLayout())
        let loc = doc.layout.locomotives[0]
        let command = Command.queryDirection(address: loc.address, decoderType: loc.decoder, descriptor: nil)
        if let (canMessage, _) = MarklinCANMessage.from(command: command), let mi = doc.interface as? MarklinInterface {
            mi.messages.append(canMessage)
        }
        return doc
    }()
    
    static var previews: some View {
        CS3ReceivedMessageView(mi: doc.interface as! MarklinInterface)
    }
}
