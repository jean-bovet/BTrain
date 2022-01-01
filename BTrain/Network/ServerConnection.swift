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
import Network

@available(macOS 10.14, *)
class ServerConnection {
    //The TCP maximum package size is 64K 65536
    let MTU = 65536
    
    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int
        
    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    var receiveMessageCallback: ((Command) -> Void)? = nil
    
    func start() {
        print("connection \(id) will start")
        connection.stateUpdateHandler = self.stateDidChange(to:)
        setupReceive()
        connection.start(queue: .main)
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("connection \(id) ready")
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }

    private func getHost() ->  NWEndpoint.Host? {
        switch connection.endpoint {
        case .hostPort(let host , _):
            return host
        default:
            return nil
        }
    }
    
    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { (data, _, isComplete, error) in
            if let data = data, !data.isEmpty {
                let msg = MarklinCANMessage.decode(from: [UInt8](data))
                print("[Server] < \(MarklinCANMessagePrinter.debugDescription(msg: msg)) - \(self.id)")
                let cmd = Command.from(message: msg)
                self.receiveMessageCallback?(cmd)
//                self.send(data: data)
            }
            if isComplete {
                self.connectionDidEnd()
            } else if let error = error {
                self.connectionDidFail(error: error)
            } else {
                self.setupReceive()
            }
        }
    }

    typealias CompletionBlock = (() -> Void)

    func send(data: Data, completion: CompletionBlock? = nil) {
        self.connection.send(content: data, completion: .contentProcessed( { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.connectionDidFail(error: error)
                    return
                }
                
                let msg = MarklinCANMessage.decode(from: [UInt8](data))
                print("[Server] > \(MarklinCANMessagePrinter.debugDescription(msg: msg)) - \(self.id)")
                
                completion?()
            }
        }))
    }
    
    func stop() {
        print("[Server] \(id) will stop")
        stop(error: nil)
    }
        
    private func connectionDidFail(error: Error) {
        print("[Server] \(id) did fail, error: \(error)")
        stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("[Server] \(id) did end")
        stop(error: nil)
    }
    
    private func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
}
