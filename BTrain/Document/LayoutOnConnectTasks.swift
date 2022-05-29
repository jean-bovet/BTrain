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

final class LayoutOnConnectTasks: ObservableObject {

    let layout: Layout
    let layoutController: LayoutController
    let interface: CommandInterface
    
    // Property used to keep track of the progress when activating the turnouts
    // when connecting to the Digital Controller
    @Published var activateTurnoutPercentage: Double? = nil

    init(layout: Layout, layoutController: LayoutController, interface: CommandInterface) {
        self.layout = layout
        self.layoutController = layoutController
        self.interface = interface
    }
    
    func performOnConnectTasks(activateTurnouts: Bool, completion: @escaping CompletionBlock) {
        queryLocomotivesDirection {
            if activateTurnouts {
                self.layoutController.go {
                    self.applyTurnoutStateToDigitalController {
                        completion()
                    }
                }
            } else {
                completion()
            }
        }
    }
    
    private func queryLocomotivesDirection(completion: @escaping CompletionBlock) {
        let trains = layout.trains.filter( { $0.enabled })
        guard !trains.isEmpty else {
            completion()
            return
        }

        var completionCount = 0
        for t in trains {
            let command = Command.queryDirection(address: t.address, decoderType: t.decoder, descriptor: nil)
            interface.execute(command: command) {
                DispatchQueue.main.async {
                    completionCount += 1
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
        
        activateTurnoutPercentage = 0.0
        var completionCount = 0
        for t in turnouts {
            layoutController.sendTurnoutState(turnout: t) {
                completionCount += 1
                self.activateTurnoutPercentage = Double(completionCount) / Double(turnouts.count)
                if completionCount == turnouts.count {
                    self.activateTurnoutPercentage = nil
                    completion()
                }
            }
        }
    }
    
}
