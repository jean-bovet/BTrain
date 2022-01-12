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
        interface.execute(command: .stop(), onCompletion: onCompletion)
    }
    
    func start(train: Identifier<Train>, withRoute route: Identifier<Route>, toBlockId: Identifier<Block>?) throws {
        // Note: the simulator holds a reference to the layout and will automatically simulate any
        // enabled route associated with a train.
        try layoutController.start(routeID: route, trainID: train, toBlockId: toBlockId)
    }
    
    func stop(train: Train) throws {
        guard let route = train.routeId else {
            throw LayoutError.trainNotAssignedToARoute(train: train)
        }
                
        try layoutController.stop(routeID: route, trainID: train.id)
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
                self.registerForFeedbackChange()
                self.registerForSpeedChange()
                self.registerForDirectionChange()
                self.registerForTurnoutChange()
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
    
    func registerForFeedbackChange() {
        interface.register(forFeedbackChange: { deviceID, contactID, value in
            if let feedback = self.layout.feedbacks.find(deviceID: deviceID, contactID: contactID) {
                feedback.detected = value == 1
            }
        })
    }
                
    func registerForSpeedChange() {
        interface.register(forSpeedChange: { address, decoder, value in
            DispatchQueue.main.async {
                if let train = self.layout.trains.find(address: address, decoder: decoder) {
                    train.speed.steps = self.interface.speedSteps(for: value, decoder: train.decoder)
                }
            }
        })
    }
    
    func registerForDirectionChange() {
        interface.register(forDirectionChange: { address, decoder, direction in
            DispatchQueue.main.async {
                if let train = self.layout.trains.find(address: address, decoder: decoder) {
                    switch(direction) {
                    case .forward:
                        if train.directionForward == false {
                            train.directionForward = true
                            try? self.layout.toggleTrainDirectionInBlock(train)
                        }
                    case .backward:
                        if train.directionForward {
                            train.directionForward = false
                            try? self.layout.toggleTrainDirectionInBlock(train)
                        }
                    case .unknown:
                        BTLogger.error("Unknown direction \(direction) for \(address.toHex())")
                    }
                } else {
                    BTLogger.error("Unknown address \(address.toHex()) for change in direction event")
                }
            }
        })
    }
    
    func registerForTurnoutChange() {
        interface.register(forTurnoutChange: { address, state, power in
            DispatchQueue.main.async {
                if let turnout = self.layout.turnouts.find(address: address) {
                    BTLogger.debug("Turnout \(turnout.name) changed state \(state) for address \(address.actualAddress.toHex())")
                    turnout.setState(value: state, for: address.actualAddress)
                    BTLogger.debug(" > Turnout \(turnout.name) changed to state \(turnout.state)")
                    self.layout.didChange()
                } else {
                    BTLogger.error("Unknown turnout for address \(address.actualAddress.toHex())")
                }
            }
        })
    }
    
}
