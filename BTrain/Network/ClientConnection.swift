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

import Foundation
import Network

@available(macOS 10.14, *)
class ClientConnection {
    
    let nwConnection: NWConnection
    let queue = DispatchQueue(label: "Client connection Q")
    
    init(nwConnection: NWConnection) {
        self.nwConnection = nwConnection
    }
    
    var didSucceedCallback: (() -> Void)? = nil
    var didReceiveCallback: ((MarklinCANMessage) -> Void)? = nil
    var didStopCallback: (() -> Void)? = nil

    func start() {
        nwConnection.stateUpdateHandler = stateDidChange(to:)
        setupReceive()
        nwConnection.start(queue: queue)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            didSucceedCallback?()
        case .failed(let error):
            connectionDidFail(error: error)
        case .cancelled:
            if let didStopCallback = self.didStopCallback {
                self.didStopCallback = nil
                didStopCallback()
            }
        default:
            break
        }
    }
    
    private func setupReceive() {
        nwConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                print("[Client] < \(data.count) bytes of data")
                // Read each CAN message, one by one. Each CAN message is 13 bytes.
                // Sometimes more than one message is received in a single data.
                let numberOfPackets = data.count / MarklinCANMessage.messageLength
                for packet in 0..<numberOfPackets {
                    let start = packet * MarklinCANMessage.messageLength
                    let end = (packet + 1) * MarklinCANMessage.messageLength
                    let slice = data[start..<end]

                    let msg = MarklinCANMessage.decode(from: [UInt8](slice))
                    print("[Client] < \(MarklinCANMessagePrinter.debugDescription(msg: msg))")
                    self.didReceiveCallback?(msg)
                }
            }
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                if case let NWError.posix(code) = error, code == .ECANCELED {
                    // Cancelled, likely because we closed the connection on purpose
                } else {
                    self.connectionDidFail(error: error)
                }
            } else {
                self.setupReceive()
            }
        }
    }
        
    private var dataQueue = ScheduledMessageQueue()
    
    func send(data: Data) {
        dataQueue.schedule { completion in
            self.nwConnection.send(content: data, completion: .contentProcessed( { error in
                let msg = MarklinCANMessage.decode(from: [UInt8](data))
                print("[Client] > \(MarklinCANMessagePrinter.debugDescription(msg: msg))")

                DispatchQueue.main.async {
                    if let error = error {
                        self.connectionDidFail(error: error)
                        return
                    }

                    completion()
                }
            }))
        }
    }

    func stop() {
        print("[Client] will stop")
        nwConnection.cancel()
    }
    
    private func connectionDidFail(error: Error) {
        print("[Client] did fail, error: \(error)")
        stop()
    }
    
    private func connectionDidEnd() {
        print("[Client] did end")
        stop()
    }
    
}
