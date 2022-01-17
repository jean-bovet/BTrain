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
        interface.execute(command: .go(), onCompletion: onCompletion)
    }
    
    func disable(onCompletion: @escaping () -> Void) {
        layoutController.stop(onCompletion: onCompletion)
    }
    
    func start(train: Identifier<Train>, withRoute route: Identifier<Route>, destination: Destination?) throws {
        // Note: the simulator holds a reference to the layout and will automatically simulate any
        // enabled route associated with a train.
        try layoutController.start(routeID: route, trainID: train, destination: destination)
    }
    
    func stop(train: Train) throws {
        try layoutController.stop(trainID: train.id, completely: true)
    }

    func finish(train: Train) throws {
        try layoutController.finish(trainID: train.id)
    }

    @discardableResult
    func connectToSimulator(completed: ((Error?) -> Void)? = nil) -> CommandInterface {
        simulator.start()
        return connect(address: "localhost", port: 15731, completed: completed)
    }
    
    @discardableResult
    func connect(address: String, port: UInt16, completed: ((Error?) -> Void)? = nil) -> CommandInterface {
        let mi = MarklinInterface(server: address, port: port)
        mi.connect {
            DispatchQueue.main.async {
                self.connected = true
                self.interface.interface = mi
                self.layoutController.interfaceChanged()
                completed?(nil)
            }
        } onError: { error in
            DispatchQueue.main.async {
                self.connected = false
                self.interface.interface = nil
                completed?(error)
            }
        } onStop: {
            DispatchQueue.main.async {
                self.connected = false
                self.interface.interface = nil
            }
        }
        return mi
    }
    
    func disconnect() {
        simulator.stop()
        interface.disconnect() { }
    }
        
    func applyTurnoutStateToDigitalController(completion: @escaping CompletionBlock) {
        let turnouts = layout.turnouts
        guard !turnouts.isEmpty else {
            completion()
            return
        }
        
        activateTurnountPercentage = 0.0
        var completionCount = 0
        for t in turnouts {
            layout.executor?.sendTurnoutState(turnout: t) {
                completionCount += 1
                self.activateTurnountPercentage = Double(completionCount) / Double(turnouts.count)
                if completionCount == turnouts.count {
                    self.activateTurnountPercentage = nil
                    completion()
                }
            }
        }
    }
    
}
