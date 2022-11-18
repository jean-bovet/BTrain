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
final class ServerConnection {
    // The TCP maximum package size is 64K 65536
    let MTU = 65536

    private static var nextID: Int = 0
    let connection: NWConnection
    let id: Int

    init(nwConnection: NWConnection) {
        connection = nwConnection
        id = ServerConnection.nextID
        ServerConnection.nextID += 1
    }

    var didStopCallback: ((Error?) -> Void)?
    var receiveMessageCallback: ((Command) -> Void)?

    func start() {
        BTLogger.network.debug("connection \(self.id) will start")
        connection.stateUpdateHandler = { [weak self] state in
            self?.stateDidChange(to: state)
        }
        setupReceive()
        connection.start(queue: .main)
    }

    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case let .waiting(error):
            connectionDidFail(error: error)
        case .ready:
            BTLogger.network.debug("connection \(self.id) ready")
        case let .failed(error):
            connectionDidFail(error: error)
        default:
            break
        }
    }

    private func getHost() -> NWEndpoint.Host? {
        switch connection.endpoint {
        case let .hostPort(host, _):
            return host
        default:
            return nil
        }
    }

    private func setupReceive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: MTU) { [weak self] data, _, isComplete, error in
            guard let sSelf = self else {
                return
            }
            if let data = data, !data.isEmpty {
                let msg = MarklinCANMessage.decode(from: [UInt8](data))
                if let description = MarklinCANMessagePrinter.debugDescription(msg: msg) {
                    BTLogger.network.debug("[Server] < \(description) - \(sSelf.id)")
                }
                let cmd = Command.from(message: msg)
                sSelf.receiveMessageCallback?(cmd)
            }
            if isComplete {
                sSelf.connectionDidEnd()
            } else if let error = error {
                sSelf.connectionDidFail(error: error)
            } else {
                sSelf.setupReceive()
            }
        }
    }

    func send(data: Data, completion: CompletionBlock? = nil) {
        let msg = MarklinCANMessage.decode(from: [UInt8](data))
        if let description = MarklinCANMessagePrinter.debugDescription(msg: msg) {
            BTLogger.network.debug("[Server] > \(description) - \(self.id)")
        }

        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.connectionDidFail(error: error)
                    return
                }

                completion?()
            }
        })
    }

    func stop() {
        BTLogger.network.debug("[Server] \(self.id) will stop")
        stop(error: nil)
    }

    private func connectionDidFail(error: Error) {
        BTLogger.network.error("[Server] \(self.id) did fail, error: \(error.localizedDescription)")
        stop(error: error)
    }

    private func connectionDidEnd() {
        BTLogger.network.debug("[Server] \(self.id) did end")
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
