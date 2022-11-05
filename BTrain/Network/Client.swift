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
final class Client {
    
    typealias OnReadyBlock = () -> Void
    typealias OnDataBlock = (MarklinCANMessage) -> Void
    typealias OnErrorBlock = (Error) -> Void
    typealias OnStopBlock = () -> Void

    let connection: ClientConnection
    let address: String
    let host: NWEndpoint.Host
    let port: NWEndpoint.Port
        
    init(address: String, port: UInt16) {
        self.address = address
        self.host = NWEndpoint.Host(address)
        self.port = NWEndpoint.Port(rawValue: port)!
        let nwConnection = NWConnection(host: self.host, port: self.port, using: .tcp)
        connection = ClientConnection(nwConnection: nwConnection)
    }
    
    deinit {
        stop()
    }
    
    func start(onReady: @escaping OnReadyBlock, onData: @escaping OnDataBlock, onError: @escaping OnErrorBlock, onStop: @escaping OnStopBlock) {
        NSLog("Client started \(host) \(port)")
        
        connection.didSucceedCallback = {
            onReady()
        }
        connection.didReceiveCallback = { message in
            onData(message)
        }
        connection.didFailCallback = { error in
            onError(error)
        }
        connection.didStopCallback = { () -> Void in
            onStop()
        }
        connection.start()
    }
    
    func stop() {
        connection.stop()
    }
    
    func send(data: Data, priority: Bool, onCompletion: @escaping () -> Void) {
        connection.send(data: data, priority: priority, onCompletion: onCompletion)
    }
        
}
