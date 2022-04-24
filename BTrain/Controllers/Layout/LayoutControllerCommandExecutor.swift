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

final class LayoutCommandExecutor {
    
    weak var layout: Layout?
    weak var interface: CommandInterface?
    
    // Queue to ensure that sending of command for each turnout does happen
    // every 100ms in order to avoid a spike in current on the real layout.
    // TODO: expose that as a settings
    let turnoutQueue = ScheduledMessageQueue(delay: 0.100, name: "Turnout")
    
    // Time until the turnout state power is turned off.
    let activationTime: TimeInterval = 0.2
        
    init(layout: Layout, interface: CommandInterface) {
        self.layout = layout
        self.interface = interface
    }
    
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        BTLogger.debug("Turnout \(turnout) state changed to \(turnout.state)")
                
        guard let interface = interface else {
            completion()
            return
        }

        let commands = turnout.stateCommands(power: 0x1)
        let idleCommands = turnout.stateCommands(power: 0x0)
        assert(commands.count == idleCommands.count)
        
        var commandCompletionCount = commands.count
        for (index, command) in commands.enumerated() {
            turnoutQueue.schedule { [weak self] qc in
                interface.execute(command: command) { [weak self] in
                    qc()
                    guard let activationTime = self?.activationTime else {
                        return
                    }
                    Timer.scheduledTimer(withTimeInterval: activationTime, repeats: false) { timer in
                        interface.execute(command: idleCommands[index]) {
                            commandCompletionCount -= 1
                            if commandCompletionCount == 0 {
                                completion()
                            }
                        }
                    }
                }
            }
        }
    }

    func sendTrainDirection(train: Train, completion: @escaping CompletionBlock) {
        BTLogger.debug("Train \(train.name) changed direction to \(train.directionForward ? "forward" : "backward" )")
        guard let interface = interface else {
            completion()
            return
        }

        let command: Command
        if train.directionForward {
            command = .direction(address: train.address, decoderType: train.decoder, direction: .forward)
        } else {
            command = .direction(address: train.address, decoderType: train.decoder, direction: .backward)
        }
        interface.execute(command: command, onCompletion: completion)
    }
        
}

