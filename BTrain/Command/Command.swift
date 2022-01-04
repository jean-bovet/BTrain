// Copyright 2021 Jean Bovet
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

// List of commands that the train interface is managing.
// These commands are agnostic of any particular manufacturer.
enum Command {
    case go(descriptor: CommandDescriptor? = nil)
    case stop(descriptor: CommandDescriptor? = nil)
    case emergencyStop(address: CommandLocomotiveAddress, descriptor: CommandDescriptor? = nil)
    case speed(address: CommandLocomotiveAddress, speed: UInt16, descriptor: CommandDescriptor? = nil)
    case forward(address: CommandLocomotiveAddress, descriptor: CommandDescriptor? = nil)
    case backward(address: CommandLocomotiveAddress, descriptor: CommandDescriptor? = nil)
    case turnout(address: CommandTurnoutAddress, state: UInt8, power: UInt8, descriptor: CommandDescriptor? = nil)
    case feedback(deviceID: UInt16, contactID: UInt16, oldValue: UInt8, newValue: UInt8, time: UInt32, descriptor: CommandDescriptor? = nil)
    
    // Asks the train interface to retrieve the locomotives description.
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
    let address: UInt32
    let decoderType: DecoderType
    
    init(_ address: UInt32, _ decoderType: DecoderType) {
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
    let `protocol`: CommandTurnoutProtocol
    
    init(_ address: UInt32, _ `protocol`: CommandTurnoutProtocol) {
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

struct CommandFeedback: Hashable {
    let deviceID: UInt16
    let contactID: UInt16
    let value: UInt8
    
    static func == (lhs: CommandFeedback, rhs: CommandFeedback) -> Bool {
        return lhs.deviceID == rhs.deviceID && lhs.contactID == rhs.contactID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(deviceID)
        hasher.combine(contactID)
    }
}

protocol CommandInterface {
    
    var feedbacks: Set<CommandFeedback> { get }
    var locomotives: [CommandLocomotive] { get }
    
    func connect(onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onUpdate: @escaping () -> Void, onStop: @escaping () -> Void)
    func disconnect(_ completion: @escaping () -> Void)
    
    func execute(command: Command)
    
    // This method executs a command and call the completion block when it
    // has completed executing. Not all command supports this completion block,
    // read each command description to know if it is used.
    func execute(command: Command, completion: @escaping () -> Void)
}
