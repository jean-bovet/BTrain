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

import Foundation

final class MarklinInterface {
        
    let client: Client
    
    let locomotiveConfig = MarklinLocomotiveConfig()
    
    var feedbacks = Set<CommandFeedback>()
    var locomotives = [CommandLocomotive]()

    typealias CompletionBlock = () -> Void
    
    var locomotivesCommandCompletionBlocks = [CompletionBlock]()
    private var disconnectCompletionBlocks: CompletionBlock?
    
    init(server: String, port: UInt16) {
        self.client = Client(host: server, port: port)
    }

    func connect(onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onUpdate: @escaping () -> Void, onStop: @escaping () -> Void) {
        client.start {
            onReady()
        } onData: { data in
            // Reach each CAN message, one by one. Each CAN message is 13 bytes.
            // Sometimes more than one message is received in a single data.
            let numberOfPackets = data.count / MarklinCANMessage.messageLength
            for packet in 0..<numberOfPackets {
                let start = packet * MarklinCANMessage.messageLength
                let end = (packet + 1) * MarklinCANMessage.messageLength
                let slice = data[start..<end]

                let msg = MarklinCANMessage.decode(from: [UInt8](slice))

                if let cmd = MarklinCommand.from(message: msg) {
                    let status = self.locomotiveConfig.process(cmd)
                    if case .completed(let locomotives) = status {
                        DispatchQueue.main.async {
                            self.locomotives = locomotives.map { CommandLocomotive(uid: $0.uid, name: $0.name, address: $0.address) }
                            self.locomotivesCommandCompletionBlocks.forEach { $0() }
                            self.locomotivesCommandCompletionBlocks.removeAll()
                        }
                    }
                } else {
                    let cmd = Command.from(message: msg)
                    if case .feedback(deviceID: let deviceID, contactID: let contactID, oldValue: _, newValue: let newValue, time: _, descriptor: _) = cmd {
                        let fb = CommandFeedback(deviceID: deviceID, contactID: contactID, value: newValue)
                        if !self.feedbacks.insert(fb).inserted {
                            self.feedbacks.update(with: fb)
                        }
                        onUpdate()
                    }
                }
            }
        } onError: { error in
            onError(error)
        } onStop: {
            DispatchQueue.main.async {
                self.disconnectCompletionBlocks?()
            }
            onStop()
        }
    }

    func disconnect(_ completion: @escaping CompletionBlock) {
        disconnectCompletionBlocks = completion
        client.stop()
    }
    
    func send(message: MarklinCANMessage) {
        client.send(data: message.data)
    }

}

extension MarklinInterface: CommandInterface {    
        
    func execute(command: Command) {
        send(message: MarklinCANMessage.from(command: command))
    }
    
    func execute(command: Command, completion: @escaping () -> Void) {
        locomotivesCommandCompletionBlocks.append(completion)
        execute(command: command)
    }

}
