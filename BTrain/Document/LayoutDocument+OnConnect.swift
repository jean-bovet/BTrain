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
    
    func performOnConnectTasks(activateTurnouts: Bool, completion: @escaping CompletionBlock) {
        queryLocomotivesDirection {
            if activateTurnouts {
                self.enable() {
                    self.applyTurnoutStateToDigitalController() {
                        completion()
                    }
                }
            } else {
                completion()
            }
        }
    }
    
    private func queryLocomotivesDirection(completion: @escaping CompletionBlock) {
        let trains = layout.trains
        guard !trains.isEmpty else {
            completion()
            return
        }

        var completionCount = 0
        for t in trains {
            let command = Command.queryDirection(address: t.address, decoderType: t.decoder, descriptor: nil)
            interface.queryDirection(command: command) { address, decoderType, direction in
                DispatchQueue.main.async {
                    completionCount += 1
                    self.layoutController.directionDidChange(address: address, decoder: decoderType, direction: direction)
                    if completionCount == trains.count {
                        completion()
                    }
                }
            }
        }
    }
    
    private func applyTurnoutStateToDigitalController(completion: @escaping CompletionBlock) {
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
