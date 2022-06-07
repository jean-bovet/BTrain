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

extension LayoutController {
    
    func registerForFeedbackChange() {
        _ = interface.register(forFeedbackChange: { [weak self] deviceID, contactID, value in
            guard let sSelf = self else {
                return
            }
            if let feedback = sSelf.layout.feedbacks.find(deviceID: deviceID, contactID: contactID) {
                feedback.detected = value == 1
                BTLogger.debug("Feedback \(feedback) changed to \(feedback.detected)")
                sSelf.runControllers(.feedbackTriggered)
            }
        })
    }
                
    func registerForDirectionChange() {
        interface.register(forDirectionChange: { [weak self] address, decoder, direction in
            self?.directionDidChange(address: address, decoder: decoder, direction: direction)
        })
    }
    
    func directionDidChange(address: UInt32, decoder: DecoderType?, direction: Command.Direction) {
        do {
            if let train = layout.trains.find(address: address, decoder: decoder) {
                BTLogger.debug("Direction changed to \(direction) for \(train.name)")
                switch(direction) {
                case .unchanged:
                    BTLogger.debug("Direction \(direction) for \(address.toHex())")

                case .forward:
                    if train.directionForward == false {
                        train.directionForward = true
                        try toggleTrainDirectionInBlock(train)
                        runControllers(.directionChanged)
                    }
                case .backward:
                    if train.directionForward {
                        train.directionForward = false
                        try toggleTrainDirectionInBlock(train)
                        runControllers(.directionChanged)
                    }
                case .unknown:
                    BTLogger.error("Unknown direction \(direction) for \(address.toHex())")
                }
            } else {
                BTLogger.error("Unknown address \(address.toHex()) for change in direction event")
            }
        } catch {
            BTLogger.error("Error handling a direction change: \(error.localizedDescription)")
        }
    }
    
    func registerForTurnoutChange() {
        interface.register(forTurnoutChange: { [weak self] address, state, power, acknowledgement in
            guard let layout = self?.layout else {
                return
            }

            // Report back only the acknowledgement for the power being set,
            // and not for the power being turned off - a turnout command
            // is actually two commands: one with power on and another following
            // about 250ms later with the power off.
            guard power == 1 else {
                return
            }
            
            if let turnout = layout.turnouts.find(address: address) {
                turnout.setActualState(value: state, for: address.actualAddress)
                if acknowledgement == false {
                    // If acknowledgement is false, it means it is a command that has been
                    // triggered by the Digital Controller and we need to reflect this by
                    // ensuring the turnout is settled with both requested and actual state
                    // being the same.
                    // TODO: unit test for that
                    turnout.requestedState = turnout.actualState
                }
                BTLogger.debug("Turnout \(turnout.name) state changed to \(state) (ack=\(acknowledgement)), power \(power), for address \(address.actualAddress.toHex()). Actual state \(turnout.actualState). Requested state \(turnout.requestedState)")
                self?.runControllers(.turnoutChanged)
            } else {
                BTLogger.error("Unknown turnout for address \(address.actualAddress.toHex())")
            }
        })
    }
    
}
