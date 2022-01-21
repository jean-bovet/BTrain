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

typealias CompletionBlock = (() -> Void)

// A protocol that the layout uses to push information to the Digital Control System
protocol LayoutCommandExecuting {
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock)
    func sendTrainDirection(train: Train)
    func sendTrainSpeed(train: Train)
}

final class LayoutCommandExecutor: LayoutCommandExecuting {
    
    let layout: Layout
    let interface: CommandInterface
    
    init(layout: Layout, interface: CommandInterface) {
        self.layout = layout
        self.interface = interface
    }
    
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        BTLogger.debug("Turnout \(turnout) state changed to \(turnout.state)")
                
        let commands = turnout.stateCommands(power: 0x1)
        var commandCompletionCount = commands.count
        commands.forEach { interface.execute(command: $0) {
            commandCompletionCount -= 1
            if commandCompletionCount == 0 {
                completion()
            }
        } }

        // Turn-off the turnout power after 250ms (activation time)
        let idleCommands = turnout.stateCommands(power: 0x0)
        Timer.scheduledTimer(withTimeInterval: 0.250, repeats: false) { timer in
            idleCommands.forEach { self.interface.execute(command: $0) {}}
        }
    }

    func sendTrainDirection(train: Train) {
        BTLogger.debug("Train \(train.name) changed direction to \(train.directionForward ? "forward" : "backward" )")
        let command: Command
        if train.directionForward {
            command = .direction(address: train.address, decoderType: train.decoder, direction: .forward)
        } else {
            command = .direction(address: train.address, decoderType: train.decoder, direction: .backward)
        }
        interface.execute(command: command) {}
    }
    
    func sendTrainSpeed(train: Train) {
        BTLogger.debug("Train \(train.name) changed speed to \(train.speed)")
        let value = interface.speedValue(for: train.speed.steps, decoder: train.decoder)
        interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: value)) {}
    }
}

