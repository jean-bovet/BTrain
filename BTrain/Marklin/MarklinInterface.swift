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

    final class CallbackRegistrar<T> {
        // Note: very important to keep the order in which the callback are registered because
        // this has many implications: for example, the layout controller is expecting to be
        // the first one to process changes from the layout before other components.
        var callbacks = OrderedDictionary<UUID, T>()
        
        func register(_ callback: T) -> UUID {
            let uuid = UUID()
            callbacks[uuid] = callback
            return uuid
        }
        
        func unregister(_ id: UUID) {
            callbacks.removeValue(forKey: id)
        }
    }

    var feedbackChangeCallbacks = CallbackRegistrar<FeedbackChangeCallback>()
    var speedChangeCallbacks = CallbackRegistrar<SpeedChangeCallback>()
    var directionChangeCallbacks = CallbackRegistrar<DirectionChangeCallback>()
    var turnoutChangeCallbacks = CallbackRegistrar<TurnoutChangeCallback>()
    var locomotivesQueryCallbacks = CallbackRegistrar<QueryLocomotiveCallback>()
    
    typealias CompletionBlock = () -> Void
    private var disconnectCompletionBlocks: CompletionBlock?
    
    /// Map of CAN message to pending completion block.
    ///
    /// This map is used to invoke the completion block for each command based on the acknowledgement from the Central Station.
    /// Note that the CAN message should be a in a raw format, meaning it should hold values that are constant between the command and its acknowledgement.
    /// For example, the hash field should be left out because it will change between the command and the corresponding acknowledgement.
    private var completionBlocks = [MarklinCANMessage:[CompletionBlock]]()

    func connect(server: String, port: UInt16, onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        client = Client(host: server, port: port)
        client?.start {
            onReady()
        } onData: { [weak self] msg in
            DispatchQueue.main.async {
                self?.onMessage(msg: msg)
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

    typealias MessageCallback = (MarklinCANMessage) -> Void
    private var messageCallbacks = [MessageCallback]()
    
    func register(for callback: @escaping MessageCallback) {
        messageCallbacks.append(callback)
    }

    func register(forFeedbackChange callback: @escaping FeedbackChangeCallback) -> UUID {
        return feedbackChangeCallbacks.register(callback)
    }
    
    func register(forSpeedChange callback: @escaping SpeedChangeCallback) -> UUID {
        return speedChangeCallbacks.register(callback)
    }
    
    func register(forDirectionChange callback: @escaping DirectionChangeCallback) -> UUID {
        return directionChangeCallbacks.register(callback)
    }
    
    func register(forTurnoutChange callback: @escaping TurnoutChangeCallback) -> UUID {
        return turnoutChangeCallbacks.register(callback)
    }

    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) -> UUID {
        return locomotivesQueryCallbacks.register(callback)
    }

    func unregister(uuid: UUID) {
        feedbackChangeCallbacks.unregister(uuid)
        speedChangeCallbacks.unregister(uuid)
        directionChangeCallbacks.unregister(uuid)
        turnoutChangeCallbacks.unregister(uuid)
        locomotivesQueryCallbacks.unregister(uuid)
    }

    private func triggerCompletionBlock(for message: MarklinCANMessage) {
        if let blocks = completionBlocks[message.raw] {
            for completionBlock in blocks {
                completionBlock()
            }
            completionBlocks[message.raw] = nil
        }
    }
    
    func onMessage(msg: MarklinCANMessage) {
        messageCallbacks.forEach { $0(msg) }
        if msg.isAck {
            handleAcknowledgment(msg)
        } else {
            handleCommand(msg)
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
                    self.locomotivesQueryCallbacks.callbacks.values.forEach { $0(locomotives) }
                }
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
            speedChangeCallbacks.callbacks.values.forEach { $0(address, decoderType, value, msg.isAck) }

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
            speedChangeCallbacks.callbacks.values.forEach { $0(address, decoderType, value, msg.isAck) }

        case .direction(let address, let decoderType, let direction, _, _):
            triggerCompletionBlock(for: msg)
            directionChangeCallbacks.callbacks.values.forEach { $0(address, decoderType, direction) }
            
        case .turnout(let address, let state, let power, _, _):
            triggerCompletionBlock(for: msg)
            turnoutChangeCallbacks.callbacks.values.forEach { $0(address, state, power, msg.isAck) }

        case .feedback(let deviceID, let contactID, _, let newValue, _, _, _):
            triggerCompletionBlock(for: msg)
            feedbackChangeCallbacks.callbacks.values.forEach { $0(deviceID, contactID, newValue) }

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
