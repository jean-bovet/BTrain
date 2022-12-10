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

@testable import BTrain
import Foundation

final class MockCommandInterface: CommandInterface {
    
    var callbacks = CommandInterfaceCallbacks()

    var speedValues = [UInt16]()
    var turnoutCommands = [Command]()

    var metrics: [Metric] {
        []
    }

    var running = true

    func pause() {
        running = false
    }

    func resume() {
        running = true
        executePendingCommands()
    }

    func connect(server _: String, port _: UInt16, onReady _: @escaping () -> Void, onError _: @escaping (Error) -> Void, onStop _: @escaping () -> Void) {}

    func disconnect(_: @escaping CompletionBlock) {}

    var pendingCommands = [(Command, CompletionBlock?)]()

    func execute(command: Command, completion: CompletionBlock?) {
        if !running {
            pendingCommands.append((command, completion))
            return
        }

        pendingCommands.append((command, completion))

        DispatchQueue.main.async {
            self.executePendingCommands()
        }
    }

    private func executePendingCommands() {
        for (command, completion) in pendingCommands {
            executeImmediate(command: command, onCompletion: completion)
        }
        pendingCommands.removeAll()
    }

    private func executeImmediate(command: Command, onCompletion: CompletionBlock?) {
        // First the completion of sending the command needs to happen
        onCompletion?()

        // Then we can trigger the callbacks for any acknowledgement from the Digital Controller
        switch command {
//        case .go(let priority, let descriptor):
//            break
//        case .stop(let priority, let descriptor):
//            break
//        case .emergencyStop(let address, let decoderType, let priority, let descriptor):
//            break
        case let .speed(address, decoderType, value, _, _):
            speedValues.append(value.value)
            for speedChangeCallback in callbacks.speedChanges.all {
                speedChangeCallback(address, decoderType, value, true)
            }

        case let .direction(address, decoderType, direction, _, _):
            for directionChangeCallback in callbacks.directionChanges.all {
                directionChangeCallback(address, decoderType, direction)
            }

        //        case .queryDirection(let address, let decoderType, let priority, let descriptor):
//            break
        case let .turnout(address, state, power, _, _):
            if power == 1 {
                turnoutCommands.append(command)
            }
            for turnoutChangeCallback in callbacks.turnoutChanges.all {
                turnoutChangeCallback(address, state, power, true /* ack */ )
            }

//        case .feedback(let deviceID, let contactID, let oldValue, let newValue, let time, let priority, let descriptor):
//            break
//        case .locomotives(let priority, let descriptor):
//            break
//        case .unknown(let command, let priority, let descriptor):
//            break
        default:
            break
        }
    }

    func speedValue(for steps: SpeedStep, decoder _: DecoderType) -> SpeedValue {
        .init(value: steps.value)
    }

    func speedSteps(for value: SpeedValue, decoder _: DecoderType) -> SpeedStep {
        .init(value: value.value)
    }
    
    func locomotiveFunctions() -> [CommandLocomotiveFunctionAttributes] {
        []
    }

}
