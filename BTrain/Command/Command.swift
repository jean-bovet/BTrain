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

/// List of commands that can be sent to a Digital Control System.
///
/// These commands are agnostic of any particular manufacturer.
enum Command {
    enum Priority {
        case high
        case normal
    }
    
    case go(priority: Priority = .high, descriptor: CommandDescriptor? = nil)
    case stop(priority: Priority = .high, descriptor: CommandDescriptor? = nil)
    case emergencyStop(address: UInt32, decoderType: DecoderType?, priority: Priority = .high, descriptor: CommandDescriptor? = nil)
    
    case speed(address: UInt32, decoderType: DecoderType?, value: SpeedValue, priority: Priority = .normal, descriptor: CommandDescriptor? = nil)
    
    enum Direction {
        case forward
        case backward
        case unknown
    }
    
    case direction(address: UInt32, decoderType: DecoderType?, direction: Direction, priority: Priority = .normal, descriptor: CommandDescriptor? = nil)
    
    case queryDirection(address: UInt32, decoderType: DecoderType?, priority: Priority = .normal, descriptor: CommandDescriptor? = nil)

    case turnout(address: CommandTurnoutAddress, state: UInt8, power: UInt8, priority: Priority = .normal, descriptor: CommandDescriptor? = nil)
    
    case feedback(deviceID: UInt16, contactID: UInt16, oldValue: UInt8, newValue: UInt8, time: UInt32, priority: Priority = .normal, descriptor: CommandDescriptor? = nil)
    
    // Asks the Digital Control System to retrieve the locomotives description.
    // This command uses the completion block of the execute() method to notify when
    // the locomotives have all been fetched
    case locomotives(priority: Priority = .normal, descriptor: CommandDescriptor? = nil)
    
    // Unknown command. Use the descriptor to find out more about its description
    // and potential hex values for debugging.
    case unknown(command: UInt8, priority: Priority = .normal, descriptor: CommandDescriptor? = nil)
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
    
    // Source: https://www.marklin-users.net/forum/posts/t27003-MM2-and-mfx-speed-steps
    var steps: UInt8 {
        switch(self) {
        case .MM:
            return 14
        case .MM2:
            return 27
        case .DCC:
            return 28
        case .MFX:
            return 126
        case .SX1:
            // Source: https://www.manualslib.com/manual/1489322/DAndh-Dh05c.html?page=26
            return 31
        }
    }

}

extension UInt32 {
    
    func actualAddress(for decoder: DecoderType?) -> UInt32 {
        switch(decoder) {
        case .MM:
            return 0x0000 + self
        case .MM2:
            return 0x0000 + self
        case .DCC:
            return 0xC000 + self
        case .MFX:
            return 0x4000 + self
        case .SX1:
            return 0x0800 + self
        case .none:
            return self
        }
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
