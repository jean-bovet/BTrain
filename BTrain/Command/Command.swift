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

// List of commands that can be sent to a Digital Control System.
// These commands are agnostic of any particular manufacturer.
enum Command {
    case go(descriptor: CommandDescriptor? = nil)
    case stop(descriptor: CommandDescriptor? = nil)
    case emergencyStop(address: CommandLocomotiveAddress, descriptor: CommandDescriptor? = nil)
    
    case speed(address: CommandLocomotiveAddress, speed: UInt16, descriptor: CommandDescriptor? = nil)
    
    enum Direction {
        case forward
        case backward
        case unknown
    }
    
    case direction(address: CommandLocomotiveAddress, direction: Direction, descriptor: CommandDescriptor? = nil)
    case queryDirection(address: CommandLocomotiveAddress, descriptor: CommandDescriptor? = nil)

    case turnout(address: CommandTurnoutAddress, state: UInt8, power: UInt8, descriptor: CommandDescriptor? = nil)
    
    case feedback(deviceID: UInt16, contactID: UInt16, oldValue: UInt8, newValue: UInt8, time: UInt32, descriptor: CommandDescriptor? = nil)
    
    // Asks the Digital Control System to retrieve the locomotives description.
    // This command uses the completion block of the execute() method to notify when
    // the locomotives have all been fetched
    case locomotives(descriptor: CommandDescriptor? = nil)
    
    // Unknown command. Use the descriptor to find out more about its description
    // and potential hex values for debugging.
    case unknown(command: UInt8, descriptor: CommandDescriptor? = nil)
}

struct CommandDescriptor {
    let data: Data
    let description: String
}

enum DecoderType: String, CaseIterable, Codable {
    case MM
    case MM2
    case DCC
    case MFX
    case SX1
}

struct CommandLocomotiveAddress: Codable, Hashable, Equatable {
    // The address of the locomotive.
    let address: UInt32
    
    // The decoder type or nil if not specified.
    let decoderType: DecoderType?
    
    init(_ address: UInt32, _ decoderType: DecoderType?) {
        self.address = address
        self.decoderType = decoderType
    }
}

enum CommandTurnoutProtocol: String, CaseIterable, Codable {
    case DCC
    case MM
}

struct CommandTurnoutAddress: Codable, Hashable, Equatable {
    let address: UInt32
    let `protocol`: CommandTurnoutProtocol?
    
    init(_ address: UInt32, _ `protocol`: CommandTurnoutProtocol?) {
        self.address = address
        self.protocol = `protocol`
    }
}

struct CommandLocomotive {
    let uid: UInt32?
    let name: String?
    let address: UInt32?
    let decoderType: DecoderType?
    
    var commandAddress: CommandLocomotiveAddress? {
        guard let address = address else {
            return nil
        }

        guard let decoderType = decoderType else {
            return nil
        }

        return .init(address, decoderType)
    }
}

protocol CommandInterface {
        
    func connect(onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void)
    func disconnect(_ completion: @escaping () -> Void)
    
    func execute(command: Command, onCompletion: @escaping () -> Void)

    typealias FeedbackChangeCallback = (_ deviceID: UInt16, _ contactID: UInt16, _ value: UInt8) -> Void
    func register(forFeedbackChange: @escaping FeedbackChangeCallback)

    typealias SpeedChangeCallback = (_ address: CommandLocomotiveAddress, _ speed: UInt16) -> Void
    func register(forSpeedChange: @escaping SpeedChangeCallback)

    typealias DirectionChangeCallback = (_ address: UInt32, _ direction: Command.Direction) -> Void
    func register(forDirectionChange: @escaping DirectionChangeCallback)

    typealias TurnoutChangeCallback = (_ address: CommandTurnoutAddress, _ state: UInt8, _ power: UInt8) -> Void
    func register(forTurnoutChange: @escaping TurnoutChangeCallback)

    // Note: this command is used internally by the MarklinInterface to query direction automatically after receiving a System Emergency Stop.
    typealias QueryDirectionCommandCompletion = (_ address:UInt32, _ direction:Command.Direction) -> Void
    func queryDirection(command: Command, completion: @escaping QueryDirectionCommandCompletion)
    
    typealias QueryLocomotiveCommandCompletion = (_ locomotives: [CommandLocomotive]) -> Void
    func queryLocomotives(command: Command, completion: @escaping QueryLocomotiveCommandCompletion)
}
