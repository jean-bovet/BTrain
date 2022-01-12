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

final class MarklinInterface {
        
    let client: Client
    
    let locomotiveConfig = MarklinLocomotiveConfig()
    
    var feedbackChangeCallbacks = [FeedbackChangeCallback]()
    var speedChangeCallbacks = [SpeedChangeCallback]()
    var directionChangeCallbacks = [DirectionChangeCallback]()
    var turnoutChangeCallbacks = [TurnoutChangeCallback]()
    
    var locomotivesCommandCompletionBlocks = [QueryLocomotiveCommandCompletion]()
    
    var directionCommandCompletionBlocks = [QueryDirectionCommandCompletion]()

    typealias CompletionBlock = () -> Void
    private var disconnectCompletionBlocks: CompletionBlock?
    
    init(server: String, port: UInt16) {
        self.client = Client(host: server, port: port)
    }

    func connect(onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        client.start {
            onReady()
        } onData: { msg in
            if let cmd = MarklinCommand.from(message: msg) {
                switch(cmd) {
                case .direction(address: let address, direction: let direction):
                    self.directionCommandCompletionBlocks.forEach { $0(address, nil, direction) }
                    self.directionCommandCompletionBlocks.removeAll()
                    
                case .configDataStream(length: _, data: _, descriptor: _):
                    let status = self.locomotiveConfig.process(cmd)
                    if case .completed(let locomotives) = status {
                        DispatchQueue.main.async {
                            let locomotives = locomotives.map { $0.commandLocomotive }
                            self.locomotivesCommandCompletionBlocks.forEach { $0(locomotives) }
                            self.locomotivesCommandCompletionBlocks.removeAll()
                        }
                    }
                }
            } else {
                let cmd = Command.from(message: msg)
                if case .feedback(deviceID: let deviceID, contactID: let contactID, oldValue: _, newValue: let newValue, time: _, descriptor: _) = cmd {
                    self.feedbackChangeCallbacks.forEach { $0(deviceID, contactID, newValue) }
                }
                if case .turnout(address: let address, state: let state, power: let power, descriptor: _) = cmd {
                    if msg.resp == 0 {
                        // Only report turnout change when the message is initiated from
                        // the Digital Controller. This is because when BTrain sends
                        // a turnout command, the Digital Controller will respond
                        // with an acknowledgement with msg.resp == 1, which should be ignored here.
                        self.turnoutChangeCallbacks.forEach { $0(address, state, power) }
                    }
                }
                if case .speed(address: let address, decoderType: let decoderType, value: let value, descriptor: _) = cmd {
                    if msg.resp == 0 {
                        self.speedChangeCallbacks.forEach { $0(address, decoderType, value) }
                    }
                }
                if case .emergencyStop(address: let address, decoderType: let decoderType, descriptor: _) = cmd {
                    // Execute a command to query the direction of the locomotive at this particular address
                    DispatchQueue.main.async {
                        self.queryDirection(command: .queryDirection(address: address, decoderType: decoderType)) { address, decoder, direction in
                            self.directionChangeCallbacks.forEach { $0(address, decoder, direction) }
                        }
                    }
                }
            }
        } onError: { error in
            onError(error)
        } onStop: {
            DispatchQueue.main.async {
                self.disconnectCompletionBlocks?()
            }
            onStop()
        }
    }

    func send(message: MarklinCANMessage, onCompletion: @escaping () -> Void) {
        client.send(data: message.data, onCompletion: onCompletion)
    }

}

extension MarklinInterface: CommandInterface {
        
    func disconnect(_ completion: @escaping CompletionBlock) {
        disconnectCompletionBlocks = completion
        client.stop()
    }
    
    func execute(command: Command, onCompletion: @escaping () -> Void) {
        send(message: MarklinCANMessage.from(command: command), onCompletion: onCompletion)
    }

    // Maximum value of the speed parameters that can be specified in the CAN message.
    static let maxCANSpeedValue = 1000

    func speedValue(for steps: UInt16, decoder: DecoderType) -> UInt16 {
        let value = Double(steps) * Double(MarklinInterface.maxCANSpeedValue) / Double(decoder.steps)
        return UInt16(value)
    }
    
    func speedSteps(for value: UInt16, decoder: DecoderType) -> UInt16 {
        let steps = TrainSpeed.UnitStep(Double(value) / Double(MarklinInterface.maxCANSpeedValue) * Double(decoder.steps))
        return steps
    }

    func register(forFeedbackChange callback: @escaping FeedbackChangeCallback) {
        feedbackChangeCallbacks.append(callback)
    }

    func register(forSpeedChange callback: @escaping SpeedChangeCallback) {
        speedChangeCallbacks.append(callback)
    }
    
    func register(forDirectionChange callback: @escaping DirectionChangeCallback) {
        directionChangeCallbacks.append(callback)
    }
    
    func register(forTurnoutChange callback: @escaping TurnoutChangeCallback) {
        turnoutChangeCallbacks.append(callback)
    }
    
    func queryDirection(command: Command, completion: @escaping QueryDirectionCommandCompletion) {
        directionCommandCompletionBlocks.append(completion)
        execute(command: command) { }
    }
    
    func queryLocomotives(command: Command, completion: @escaping QueryLocomotiveCommandCompletion) {
        locomotivesCommandCompletionBlocks.append(completion)
        execute(command: command) { }
    }

}

extension Locomotive {
    
    var commandLocomotive: CommandLocomotive {
        CommandLocomotive(uid: uid, name: name, address: address, decoderType: type?.locomotiveDecoderType ?? .MFX)
    }
}

extension String {
    
    var locomotiveDecoderType: DecoderType {
        switch(self) {
        case "mfx":
            return .MFX
        case "mm_prg":
            return .MM
        case "mm2_prg":
            return .MM2
        case "mm2_dil8":
            return .MM
        case "dcc":
            return .DCC
        case "sx1":
            return .SX1
        default:
            return .MFX
        }
    }
}
