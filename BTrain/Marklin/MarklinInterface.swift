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

/// Implementation of the CommandInterface for the Marklin Central Station 3
final class MarklinInterface: CommandInterface, ObservableObject {
    var callbacks = CommandInterfaceCallbacks()

    var client: Client?

    let locomotivesFetcher = MarklinFetchLocomotives()

    typealias CompletionBlock = () -> Void
    private var disconnectCompletionBlocks: CompletionBlock?

    /// True if CAN messages should be collected. The ``messages`` will be populated as the message arrive.
    @Published var collectMessages = false

    /// Public array of messages that the interface received from the CS3. Used mainly
    /// for debugging purpose.
    @Published var messages = [MarklinCANMessage]()

    /// Map of CAN message to pending completion block.
    ///
    /// This map is used to invoke the completion block for each command based on the acknowledgement from the Central Station.
    /// Note that the CAN message should be a in a raw format, meaning it should hold values that are constant between the command and its acknowledgement.
    /// For example, the hash field should be left out because it will change between the command and the corresponding acknowledgement.
    private var completionBlocks = [MarklinCANMessage: [CompletionBlock]]()

    private let resources = MarklinInterfaceResources()
        
    func connect(server: String, port: UInt16, onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        client = Client(address: server, port: port)
        if let client = client {
            client.start { [weak self] in
                self?.resources.fetchResources(server: client.address) {
                    onReady()
                }
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
    }

    func disconnect(_ completion: @escaping CompletionBlock) {
        disconnectCompletionBlocks = completion
        completionBlocks.removeAll()
        client?.stop()
    }

    func execute(command: Command, completion: CompletionBlock? = nil) {
        if case .locomotives = command, let server = client?.address {
            locomotivesFetcher.fetchLocomotives(server: server) { [weak self] locomotives in
                if let locomotives = locomotives {
                    self?.callbacks.locomotivesQueries.all.forEach { $0(locomotives) }
                }
                completion?()
            }
        } else {
            guard let (message, priority) = MarklinCANMessage.from(command: command) else {
                completion?()
                return
            }

            send(message: message, priority: priority, completion: completion)
        }
    }

    // Maximum value of the speed parameters that can be specified in the CAN message.
    static let maxCANSpeedValue = 1000

    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        let v = Double(steps.value) * Double(MarklinInterface.maxCANSpeedValue) / Double(decoder.steps)
        let value = ceil(v)
        return SpeedValue(value: min(UInt16(MarklinInterface.maxCANSpeedValue), UInt16(value)))
    }

    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        guard value.value > 0 else {
            return .zero
        }

        let adjustedValue = min(value.value, UInt16(MarklinInterface.maxCANSpeedValue))
        let v = Double(adjustedValue) / Double(MarklinInterface.maxCANSpeedValue) * Double(decoder.steps)
        let roundedSteps = round(v)
        if roundedSteps == 0 {
            let ceiledSteps = ceil(v)
            return SpeedStep(value: UInt16(ceiledSteps))
        } else {
            return SpeedStep(value: UInt16(roundedSteps))
        }
    }

    func attributes(about function: CommandLocomotiveFunction) -> CommandLocomotiveFunctionAttributes? {
        resources.attributes(about: function)
    }

    // MARK: -
    
    func onMessage(msg: MarklinCANMessage) {
        if collectMessages {
            messages.append(msg)
        }
        if msg.isAck {
            handleAcknowledgment(msg)
        } else {
            handleCommand(msg)
        }
    }

    static func isKnownMessage(msg: MarklinCANMessage) -> Bool {
        if MarklinCommand.from(message: msg) != nil {
            return true
        } else {
            let cmd = Command.from(message: msg)
            if case .unknown = cmd {
                return false
            } else {
                return true
            }
        }
    }

    private func handleCommand(_ msg: MarklinCANMessage) {
        if let cmd = MarklinCommand.from(message: msg) {
            // Handle any Marklin-specific command first
            switch cmd {
            case .configDataStream(length: _, data: _, descriptor: _):
                break
            }
            return
        }

        let cmd = Command.from(message: msg)
        switch cmd {
        case let .emergencyStop(address, decoderType, _, _):
            // Execute a command to query the direction of the locomotive at this particular address
            // The response from this command is going to be processed below in the case .direction
            execute(command: .queryDirection(address: address, decoderType: decoderType))

        case let .speed(address, decoderType, value, _, _):
            callbacks.speedChanges.all.forEach { $0(address, decoderType, value, msg.isAck) }

        default:
            break
        }
    }

    private func handleAcknowledgment(_ msg: MarklinCANMessage) {
        if let cmd = MarklinCommand.from(message: msg) {
            // Handle any Marklin-specific command first
            switch cmd {
            case .configDataStream:
                break // ignore ack for this command
            }
            return
        }

        // Handle generic command
        let cmd = Command.from(message: msg)
        switch cmd {
        case .go:
            triggerCompletionBlock(for: msg)
            callbacks.stateChanges.all.forEach { $0(true) }

        case .stop:
            triggerCompletionBlock(for: msg)
            callbacks.stateChanges.all.forEach { $0(false) }

        case let .speed(address, decoderType, value, _, _):
            triggerCompletionBlock(for: msg)
            callbacks.speedChanges.all.forEach { $0(address, decoderType, value, msg.isAck) }

        case let .direction(address, decoderType, direction, _, _):
            triggerCompletionBlock(for: msg)
            callbacks.directionChanges.all.forEach { $0(address, decoderType, direction) }

        case let .turnout(address, state, power, _, _):
            triggerCompletionBlock(for: msg)
            callbacks.turnoutChanges.all.forEach { $0(address, state, power, msg.isAck) }

        case let .feedback(deviceID, contactID, _, newValue, _, _, _):
            triggerCompletionBlock(for: msg)
            callbacks.feedbackChanges.all.forEach { $0(deviceID, contactID, newValue) }

        case .locomotives:
            triggerCompletionBlock(for: msg)

        default:
            break
        }
    }

    private func triggerCompletionBlock(for message: MarklinCANMessage) {
        if let blocks = completionBlocks[message.raw] {
            for completionBlock in blocks {
                completionBlock()
            }
            completionBlocks[message.raw] = nil
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

extension MarklinCS3.Lok {
    var decoderType: DecoderType? {
        switch dectyp {
        case "mfx+", "mfx":
            return .MFX
        case "mm":
            return .MM
        default:
            return nil
        }
    }

    func toCommand(icon: Data?) -> CommandLocomotive {
        let actualFunctions = funktionen.filter({$0.typ2 != 0})
        let functions = actualFunctions.map { CommandLocomotiveFunction(identifier: $0.typ2 )}
        return CommandLocomotive(uid: uid.valueFromHex, name: name, address: address, maxSpeed: tachomax, decoderType: decoderType, icon: icon, functions: functions)
    }
}

extension String {
    var locomotiveDecoderType: DecoderType {
        switch self {
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
