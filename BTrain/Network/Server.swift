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

    var didAcceptConnection: ((ServerConnection) -> Void)?

    /// Internal callback block that will be invoked when the listener has been cancelled
    private var didCancelListener: (() -> Void)?

    /// Map of connections with their IDs as keys
    private var connectionsByID: [Int: ServerConnection] = [:]

    var connections: [ServerConnection] {
        connectionsByID.map {
            $0.value
        }
    }

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port)!
        listener = try! NWListener(using: .tcp, on: self.port)
    }

    deinit {
        stop {}
    }

    func start() throws {
        BTLogger.network.debug("Server starting at port \(self.port.debugDescription)...")

        listener.stateUpdateHandler = { [weak self] state in
            self?.stateDidChange(to: state)
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.didAccept(nwConnection: connection)
        }
        listener.start(queue: .main)
    }

    func stateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
            BTLogger.network.debug("Server ready.")
        case let .failed(error):
            BTLogger.network.error("Server failure, error: \(error.localizedDescription)")
        case .cancelled:
            BTLogger.network.debug("Server listener has been cancelled.")
            didCancelListener?()
            didCancelListener = nil
        default:
            break
        }
    }

    private func didAccept(nwConnection: NWConnection) {
        let connection = ServerConnection(nwConnection: nwConnection)
        connectionsByID[connection.id] = connection
        connection.didStopCallback = { [weak self] _ in
            self?.connectionDidStop(connection)
        }
        connection.start()
        didAcceptConnection?(connection)
        BTLogger.network.debug("server did open connection \(connection.id)")
    }

    private func connectionDidStop(_ connection: ServerConnection) {
        connectionsByID.removeValue(forKey: connection.id)
        BTLogger.network.debug("server did close connection \(connection.id)")
    }

    func stop(_ completion: @escaping CompletionBlock) {
        listener.newConnectionHandler = nil
        if listener.state != .cancelled {
            assert(didCancelListener == nil, "Cancel listener block should be nil")
            didCancelListener = {
                completion()
            }
            listener.cancel()
        } else {
            completion()
        }
        for connection in connectionsByID.values {
            connection.didStopCallback = nil
            connection.stop()
        }
        connectionsByID.removeAll()
    }
}
