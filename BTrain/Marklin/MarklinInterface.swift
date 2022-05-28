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
    
    /// Map of CAN message to pending completion block.
    ///
    /// The CAN message is of type ``MarklinCANMessageRaw`` which does not contain the hash nor the response bit. This allows
    /// for easy comparison between a message sent and a message received (see description of ``MarklinCANMessageRaw``).
    private var completionBlocks = [MarklinCANMessageRaw:[CompletionBlock]]()

    func connect(server: String, port: UInt16, onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        client = Client(host: server, port: port)
        client?.start {
            onReady()
        } onData: { [weak self] msg in
            DispatchQueue.main.async {
                if msg.isAck {
                    self?.handleAcknowledgment(msg)
                } else {
                    self?.handleCommand(msg)
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
        completionBlocks.removeAll()
        client?.stop()
    }
        
    func execute(command: Command, completion: CompletionBlock? = nil) {
        guard let (message, priority) = MarklinCANMessage.from(command: command) else {
            completion?()
            return
        }
                        
        send(message: message, priority: priority, completion: completion)
    }
    
    // Maximum value of the speed parameters that can be specified in the CAN message.
    static let maxCANSpeedValue = 1000

    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        let value = round(Double(steps.value) * Double(MarklinInterface.maxCANSpeedValue) / Double(decoder.steps))
        return SpeedValue(value: UInt16(value))
    }
    
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        let steps = round(Double(value.value) / Double(MarklinInterface.maxCANSpeedValue) * Double(decoder.steps))
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

    private func triggerCompletionBlock(for message: MarklinCANMessage) {
        triggerCompletionBlock(for: message.raw)
    }
    
    private func triggerCompletionBlock(for rawMessage: MarklinCANMessageRaw) {
        if let blocks = completionBlocks[rawMessage] {
            for completionBlock in blocks {
                completionBlock()
            }
            completionBlocks[rawMessage] = nil
        }
    }
    
    private func handleCommand(_ msg: MarklinCANMessage) {
        if let cmd = MarklinCommand.from(message: msg) {
            // Handle any Marklin-specific command first
            switch(cmd) {
            case .configDataStream(length: _, data: _, descriptor: _):
                let status = locomotiveConfig.process(cmd)
                if case .completed(let locomotives) = status {
                    let locomotives = locomotives.map { $0.commandLocomotive }
                    self.locomotivesQueryCallbacks.forEach { $0(locomotives) }
                }
            case .queryDirectionResponse(_, _, _, _):
                break
            }
            return
        }
        
        let cmd = Command.from(message: msg)
        switch cmd {
        case .emergencyStop(let address, let decoderType, _, _):
            // Execute a command to query the direction of the locomotive at this particular address
            // The response from this command is going to be processed below in the case .direction
            execute(command: .queryDirection(address: address, decoderType: decoderType))

        case .speed(let address, let decoderType, let value, _, _):
            speedChangeCallbacks.forEach { $0(address, decoderType, value, msg.isAck) }

        default:
            break
        }
    }
    
    private func handleAcknowledgment(_ msg: MarklinCANMessage) {
        if let cmd = MarklinCommand.from(message: msg) {
            // Handle any Marklin-specific command first
            switch(cmd) {
            case .configDataStream(_, _, _):
                break // ignore ack for this command

            case .queryDirectionResponse(address: let address, decoderType: let decoderType, direction: let direction, descriptor: _):
                directionChangeCallbacks.forEach { $0(address, decoderType, direction) }
                
                // This command is sent back from the Central Station after a .queryDirection() command
                // has been sent. We need to remove the byte5 that holds the direction parameter in order
                // to correctly invoke the completion block.
                let command = MarklinCANMessageFactory.queryDirection(addr: address)
                triggerCompletionBlock(for: command.raw)
            }
            return
        }

        // Handle generic command
        let cmd = Command.from(message: msg)
        switch cmd {
        case .go(_, _):
            triggerCompletionBlock(for: msg)
            
        case .stop(_, _):
            triggerCompletionBlock(for: msg)

        case .speed(let address, let decoderType, let value, _, _):
            triggerCompletionBlock(for: msg)
            speedChangeCallbacks.forEach { $0(address, decoderType, value, msg.isAck) }

        case .direction(let address, let decoderType, let direction, _, _):
            triggerCompletionBlock(for: msg)
            directionChangeCallbacks.forEach { $0(address, decoderType, direction) }
            
        case .turnout(let address, let state, let power, _, _):
            triggerCompletionBlock(for: msg)
            turnoutChangeCallbacks.forEach { $0(address, state, power, msg.isAck) }

        case .feedback(let deviceID, let contactID, _, let newValue, _, _, _):
            triggerCompletionBlock(for: msg)
            feedbackChangeCallbacks.forEach { $0.value(deviceID, contactID, newValue) }

        case .locomotives(_, _):
            triggerCompletionBlock(for: msg)

        default:
            break
        }
    }
    
    private func send(message: MarklinCANMessage, priority: Command.Priority, completion: CompletionBlock?) {
        guard let client = client else {
            BTLogger.error("Cannot send message to Digital Controller because the client is nil!")
            completion?()
            return
        }
        
        if let completion = completion {
            completionBlocks[message.raw] = (completionBlocks[message.raw] ?? []) + [completion]
        }

        client.send(data: message.data, priority: priority == .high) {
            // no-op as we don't care about when the message is done being sent down the wire
        }
    }
        
}

extension MarklinInterface: MetricsProvider {
    var metrics: [Metric] {
        if let queue = client?.connection.dataQueue {
            return [.init(id: queue.name, value: String(queue.scheduledCount))]
        } else {
            return []
        }
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
