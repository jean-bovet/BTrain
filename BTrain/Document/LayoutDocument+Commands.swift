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

extension LayoutDocument {
    func enable(onCompletion: @escaping () -> Void) {
        layoutController.go(onCompletion: onCompletion)
    }

    func disable(onCompletion: @escaping () -> Void) {
        layoutController.stop(onCompletion: onCompletion)
    }

    func start(train: Identifier<Train>, withRoute route: Identifier<Route>, destination: Destination?) throws {
        // Note: the simulator holds a reference to the layout and will automatically simulate any
        // enabled route associated with a train.
        try layoutController.start(routeID: route, trainID: train, destination: destination)
    }

    func startAll() {
        layoutController.startAll()
    }

    func stop(train: Train) {
        layoutController.stop(train: train)
    }

    func stopAll() {
        layoutController.stopAll(includingManualTrains: false)
    }

    func finish(train: Train) {
        layoutController.finish(train: train)
    }

    func finishAll() {
        layoutController.finishAll()
    }

    func connectToSimulator(enable: Bool, completed: ((Error?) -> Void)? = nil) {
        simulator.start()
        connect(address: "localhost", port: simulator.localPort) { [weak self] error in
            if enable {
                self?.enable {
                    completed?(nil)
                }
            } else {
                completed?(error)
            }
        }
    }

    func connect(address: String, port: UInt16, completed: ((Error?) -> Void)? = nil) {
        interface.connect(server: address, port: port) { [weak self] in
            DispatchQueue.main.async {
                self?.connected = true
                completed?(nil)
            }
        } onError: { [weak self] error in
            DispatchQueue.main.async {
                self?.connected = false
                completed?(error)
            }
        } onStop: { [weak self] in
            DispatchQueue.main.async {
                self?.connected = false
            }
        }
    }

    func disconnect(_ completion: @escaping CompletionBlock) {
        simulator.stop {
            self.interface.execute(command: .stop()) {
                self.interface.disconnect {
                    completion()
                }
            }
        }
    }
}
