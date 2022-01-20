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
class Server {
    let port: NWEndpoint.Port
    let listener: NWListener
    
    var didAcceptConnection: ((ServerConnection) -> Void)? = nil

    private var connectionsByID: [Int: ServerConnection] = [:]
    
    var connections: [ServerConnection] {
        return connectionsByID.map { $0.value }
    }
    
    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
        listener = try! NWListener(using: .tcp, on: self.port)
    }
    
    func start() throws {
        NSLog("Server starting...")
        listener.stateUpdateHandler = self.stateDidChange(to:)
        listener.newConnectionHandler = self.didAccept(nwConnection:)
        listener.start(queue: .main)
    }
    
    func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
            NSLog("Server ready.")
        case .failed(let error):
            NSLog("Server failure, error: \(error.localizedDescription)")
        default:
            break
        }
    }
        
    private func didAccept(nwConnection: NWConnection) {
        let connection = ServerConnection(nwConnection: nwConnection)
        self.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection)
        }
        connection.start()
        didAcceptConnection?(connection)
        NSLog("server did open connection \(connection.id)")
    }
    
    private func connectionDidStop(_ connection: ServerConnection) {
        self.connectionsByID.removeValue(forKey: connection.id)
        NSLog("server did close connection \(connection.id)")
    }
    
    func stop() {
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        for connection in self.connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        connectionsByID.removeAll()
    }
}

