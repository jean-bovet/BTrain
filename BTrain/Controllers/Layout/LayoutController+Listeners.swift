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
        interface.callbacks.register(forFeedbackChange: { [weak self] deviceID, contactID, value in
            guard let sSelf = self else {
                return
            }
            if let feedback = sSelf.layout.feedbacks.find(deviceID: deviceID, contactID: contactID) {
                feedback.detected = value == 1
                BTLogger.debug("Feedback \(feedback) changed to \(feedback.detected)")                
                sSelf.runControllers(.feedbackTriggered(feedback))
            }
            sSelf.lastDetectedFeedback = FeedbackAttributes(deviceID: deviceID, contactID: contactID)
        })
    }
                
    func registerForDirectionChange() {
        interface.callbacks.register(forDirectionChange: { [weak self] address, decoder, direction in
            self?.directionDidChange(address: address, decoder: decoder, direction: direction)
        })
    }
    
    func directionDidChange(address: UInt32, decoder: DecoderType?, direction: Command.Direction) {
        do {
            if let loc = layout.locomotives.find(address: address, decoder: decoder) {
                BTLogger.debug("Direction changed to \(direction) for \(loc.name)")
                var directionChanged = false
                switch(direction) {
                case .unchanged:
                    BTLogger.debug("Direction \(direction) for \(address.toHex())")

                case .forward:
                    if loc.directionForward == false {
                        loc.directionForward = true
                        directionChanged = true
                    }
                case .backward:
                    if loc.directionForward {
                        loc.directionForward = false
                        directionChanged = true
                    }
                case .unknown:
                    BTLogger.error("Unknown direction \(direction) for \(address.toHex())")
                }
                
                if directionChanged {
                    if let train = layout.train(forLocomotive: loc) {
                        try toggleTrainDirectionInBlock(train)
                        runControllers(.directionChanged(train))
                    }
                }
            } else {
                BTLogger.error("Unknown address \(address.toHex()) for change in direction event")
            }
        } catch {
            BTLogger.error("Error handling a direction change: \(error.localizedDescription)")
        }
    }
    
    func registerForTurnoutChange() {
        interface.callbacks.register(forTurnoutChange: { [weak self] address, state, power, acknowledgement in
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
            
            // We are only interested in acknowledgment messages which confirm
            // the actual state of a turnout.
            guard acknowledgement == true else {
                return
            }
            
            if let turnout = layout.turnouts.find(address: address) {
                turnout.setActualState(value: state, for: address.actualAddress)
                BTLogger.debug("Turnout \(turnout.name) state changed to \(state) (ack=\(acknowledgement)), power \(power), for address \(address.actualAddress.toHex()). Actual state \"\(turnout.actualState)\" (value=\(turnout.actualStateValue)). Requested state \"\(turnout.requestedState)\" (value=\(turnout.requestedStateValue))")
                self?.runControllers(.turnoutChanged(turnout))
            } else {
                BTLogger.error("Unknown turnout for address \(address.actualAddress.toHex())")
            }
        })
    }
    
}
