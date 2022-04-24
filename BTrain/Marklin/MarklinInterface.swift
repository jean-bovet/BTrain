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
import OrderedCollections

final class MarklinInterface: CommandInterface {
        
    var client: Client?
    
    let locomotiveConfig = MarklinLocomotiveConfig()
    
    // Note: very important to keep the order in which the callback are registered because
    // this has many implications: for example, the layout controller is expecting to be
    // the first one to process changes from the layout before other components.
    var feedbackChangeCallbacks = OrderedDictionary<UUID, FeedbackChangeCallback>()
        
    /// These callbacks are invoked when the speed is changed either by the Digital Controller (a message is received from the Digital Controller)
    /// or from an action from BTrain (a message is sent to the Digital Controller).
    var speedChangeCallbacks = [SpeedChangeCallback]()
    
    var directionChangeCallbacks = [DirectionChangeCallback]()
    var turnoutChangeCallbacks = [TurnoutChangeCallback]()
    var locomotivesQueryCallbacks = [QueryLocomotiveCallback]()
    
    typealias CompletionBlock = () -> Void
    private var disconnectCompletionBlocks: CompletionBlock?
    
    func connect(server: String, port: UInt16, onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        client = Client(host: server, port: port)
        client?.start {
            onReady()
        } onData: { [weak self] msg in
            if let cmd = MarklinCommand.from(message: msg) {
                switch(cmd) {
                case .configDataStream(length: _, data: _, descriptor: _):
                    let status = self?.locomotiveConfig.process(cmd)
                    if case .completed(let locomotives) = status {
                        DispatchQueue.main.async {
                            let locomotives = locomotives.map { $0.commandLocomotive }
                            self?.locomotivesQueryCallbacks.forEach { $0(locomotives) }
                        }
                    }
                }
            } else {
                let cmd = Command.from(message: msg)
                if case .feedback(deviceID: let deviceID, contactID: let contactID, oldValue: _, newValue: let newValue, time: _, priority: _, descriptor: _) = cmd {
                    self?.feedbackChangeCallbacks.forEach { $0.value(deviceID, contactID, newValue) }
                }
                if case .turnout(address: let address, state: let state, power: let power, priority: _, descriptor: _) = cmd {
                    if msg.resp == 0 {
                        // Only report turnout change when the message is initiated from
                        // the Digital Controller. This is because when BTrain sends
                        // a turnout command, the Digital Controller will respond
                        // with an acknowledgement with msg.resp == 1, which should be ignored here.
                        self?.turnoutChangeCallbacks.forEach { $0(address, state, power) }
                    }
                }
                if case .speed(address: let address, decoderType: let decoderType, value: let value, priority: _, descriptor: _) = cmd {
                    if msg.resp == 0 {
                        self?.speedChangeCallbacks.forEach { $0(address, decoderType, value) }
                    }
                }
                if case .emergencyStop(address: let address, decoderType: let decoderType, priority: _, descriptor: _) = cmd {
                    // Execute a command to query the direction of the locomotive at this particular address
                    DispatchQueue.main.async {
                        // The response from this command is going to be processed below in the case .direction
                        self?.execute(command: .queryDirection(address: address, decoderType: decoderType)) { }
                    }
                }
                if case .direction(address: let address, decoderType: let decoderType, direction: let direction, priority: _, descriptor: _) = cmd {
                    self?.directionChangeCallbacks.forEach { $0(address, decoderType, direction) }
                }
            }
        } onError: { [weak self] error in
            self?.client = nil
            onError(error)
        } onStop: { [weak self] in
            DispatchQueue.main.async {
                self?.disconnectCompletionBlocks?()
            }
            self?.client = nil
            onStop()
        }
    }

    func disconnect(_ completion: @escaping CompletionBlock) {
        disconnectCompletionBlocks = completion
        client?.stop()
    }
    
    func execute(command: Command, onCompletion: @escaping () -> Void) {
        guard let (message, priority) = MarklinCANMessage.from(command: command) else {
            onCompletion()
            return
        }
        
        // Invoke the speed change callbacks when the speed is effectively changed.
        if case .speed(address: let address, decoderType: let decoderType, value: let value, priority: _, descriptor: _) = command {
            self.speedChangeCallbacks.forEach { $0(address, decoderType, value) }
        }
        
        send(message: message, priority: priority, onCompletion: onCompletion)
    }

    // Maximum value of the speed parameters that can be specified in the CAN message.
    static let maxCANSpeedValue = 1000

    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        let value = Double(steps.value) * Double(MarklinInterface.maxCANSpeedValue) / Double(decoder.steps)
        return SpeedValue(value: UInt16(value))
    }
    
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        let steps = Double(value.value) / Double(MarklinInterface.maxCANSpeedValue) * Double(decoder.steps)
        return SpeedStep(value: UInt16(steps))
    }

    func register(forFeedbackChange callback: @escaping FeedbackChangeCallback) -> UUID {
        let uuid = UUID()
        feedbackChangeCallbacks[uuid] = callback
        return uuid
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

    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) {
        locomotivesQueryCallbacks.append(callback)
    }

    func unregister(uuid: UUID) {
        feedbackChangeCallbacks.removeValue(forKey: uuid)
    }

    private func send(message: MarklinCANMessage, priority: Command.Priority, onCompletion: @escaping () -> Void) {
        guard let client = client else {
            BTLogger.error("Cannot send message to Digital Controller because the client is nil!")
            onCompletion()
            return
        }
        
        client.send(data: message.data, priority: priority == .high, onCompletion: onCompletion)
    }
        
}

extension Locomotive {
    
    var commandLocomotive: CommandLocomotive {
        CommandLocomotive(uid: uid, name: name, address: address, maxSpeed: vmax, decoderType: type?.locomotiveDecoderType ?? .MFX)
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
