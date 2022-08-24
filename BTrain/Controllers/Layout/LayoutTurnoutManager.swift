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

/// Each time a turnout state is changed, this class is used to apply that change to the Digital Controller
/// by sending the appropriate commands to the turnout. This class also ensures that turnout commands
/// are not sent too fast in order to avoid overwhelming the Digital Controller power command.
final class LayoutTurnoutManager {
    
    /// The command interface to send the command to
    let interface: CommandInterface
    
    /// Queue to ensure that sending of command for each turnout does happen
    /// every 250ms in order to avoid a spike in current on the real layout.
    static let turnoutDelay = 0.250 * BaseTimeFactor
        
    /// Internal turnout queue
    let turnoutQueue = ScheduledMessageQueue(delay: turnoutDelay, name: "Turnout")
    
    internal init(interface: CommandInterface) {
        self.interface = interface
        
        // Note: when the Digital Controller is disabled or enabled, ensure
        // the turnout queue is also properly setup
        interface.callbacks.stateChanges.register { [weak self] enabled in
            if enabled {
                self?.turnoutQueue.enable()
            } else {
                self?.turnoutQueue.disable()
            }
        }
    }
    
    /// Send the turnout requested state to the Digital Controller
    /// - Parameters:
    ///   - turnout: the turnout whose requested state should be sent to the Digital Controller
    ///   - completion: a completion block when the Digital Controller has acknowledged the turnout change
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        BTLogger.debug("Turnout \(turnout) requested state to \(turnout.requestedState)")
                
        let commands = turnout.requestedStateCommands(power: 0x1)
        let idleCommands = turnout.requestedStateCommands(power: 0x0)
        assert(commands.count == idleCommands.count)
        
        // Time until the turnout state power is turned off.
        let activationTime: TimeInterval = 0.2 * BaseTimeFactor

        var commandCompletionCount = commands.count
        for (index, command) in commands.enumerated() {
            turnoutQueue.schedule { [weak self] qc in
                self?.interface.execute(command: command) {
                    qc()
                    Timer.scheduledTimer(withTimeInterval: activationTime, repeats: false) { [weak self] timer in
                        self?.interface.execute(command: idleCommands[index]) {
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

}

