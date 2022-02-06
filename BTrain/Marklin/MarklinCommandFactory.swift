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

extension MarklinCommand {
    
    static func from(message: MarklinCANMessage) -> MarklinCommand? {
        let cmd = message.command
        if cmd == 0x21 {
            // Receiving the config data stream
            // The first packet will be like:
            // 0x0042 bf46 06 00 00 05 f3 ec c6 0000
            // Then
            // 0x0042bf46 08 b6e865b108245b4e
            // 0x0042bf46 08 af59f558cdabf574
            if message.dlc == 0x06 {
                // First packet, read the length in bytes
                let length: UInt32 = UInt32(message.byte0) << 24 | UInt32(message.byte1) << 16 | UInt32(message.byte2) << 8 | UInt32(message.byte3) << 0
                let descriptor = CommandDescriptor(data: message.data, description: "\(cmd.toHex()) configuration data, length \(length)")
                return .configDataStream(length: length, data: [], descriptor: descriptor)
            } else if message.dlc == 0x08 {
                // Subsequent packets
                var data = [UInt8]()
                data.append(message.byte0)
                data.append(message.byte1)
                data.append(message.byte2)
                data.append(message.byte3)
                data.append(message.byte4)
                data.append(message.byte5)
                data.append(message.byte6)
                data.append(message.byte7)
                let descriptor = CommandDescriptor(data: message.data, description: "\(cmd.toHex()) configuration data: \(Data(data) as NSData)")
                return .configDataStream(length: nil, data: data, descriptor: descriptor)
            }
        }
        return nil
    }
    
}

extension Command {
    
    static func from(message: MarklinCANMessage) -> Command {
        let cmd = message.command
        if cmd == 0x00 && message.byte4 == 0x1 {
            return .go(descriptor: CommandDescriptor(data: message.data, description: "0x00 System Go"))
        }
        if cmd == 0x00 && message.byte4 == 0x0 {
            return .stop(descriptor: CommandDescriptor(data: message.data, description: "0x00 System Stop"))
        }
        if cmd == 0x00 && message.byte4 == 0x3 {
            let address: UInt32 = UInt32(message.byte0) << 24 | UInt32(message.byte1) << 16 | UInt32(message.byte2) << 8 | UInt32(message.byte3) << 0
            return .emergencyStop(address: address, decoderType: nil, descriptor: CommandDescriptor(data: message.data, description: "0x00 System Emergency Stop"))
        }
        if cmd == 0x04 {
            let address: UInt32 = UInt32(message.byte0) << 24 | UInt32(message.byte1) << 16 | UInt32(message.byte2) << 8 | UInt32(message.byte3) << 0
            let value: UInt16 = UInt16(message.byte4) << 8 | UInt16(message.byte5) << 0
            return .speed(address: address, decoderType: nil, value: SpeedValue(value: value),
                          descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) speed \(value) for \(address.toHex())"))
        }
        if cmd == 0x05 {
            let address: UInt32 = UInt32(message.byte0) << 24 | UInt32(message.byte1) << 16 | UInt32(message.byte2) << 8 | UInt32(message.byte3) << 0
            if message.dlc == 4 {
                if message.resp == 1 {
                    // Response to a query direction
                    switch(message.byte4) {
                    case 0: // no change
                        break
                    case 1: // forward
                        return .direction(address: address, decoderType: nil, direction: .forward,
                                        descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) forward for \(address.toHex())"))
                    case 2: // backward
                        return .direction(address: address, decoderType: nil, direction: .backward,
                                         descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) backward for \(address.toHex())"))
                    case 3: // toggle
                        break
                    default: // unknown
                        break
                    }
                } else {
                    // Query of direction.
                    return .queryDirection(address: address, decoderType: nil,
                                           descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) query direction for \(address.toHex())"))
                }
            } else {
                // Set direction
                switch(message.byte4) {
                case 0: // no change
                    break
                case 1: // forward
                    return .direction(address: address, decoderType: nil, direction: .forward,
                                    descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) forward for \(address.toHex())"))
                case 2: // backward
                    return .direction(address: address, decoderType: nil, direction: .backward,
                                     descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) backward for \(address.toHex())"))
                case 3: // toggle
                    break
                default: // unknown
                    break
                }
            }
        }
        if cmd == 0x0B {
            let address: UInt32 = UInt32(message.byte0) << 24 | UInt32(message.byte1) << 16 | UInt32(message.byte2) << 8 | UInt32(message.byte3) << 0
            let state: UInt8 = message.byte4
            let power: UInt8 = message.byte5
            return .turnout(address: CommandTurnoutAddress(address, nil),
                            state: state, power: power,
                            descriptor: CommandDescriptor(data: message.data, description: "\(cmd.toHex()) accessory \(state)-\(power) for \(address.toHex())"))
        }
        if cmd == 0x11 {
            let deviceID: UInt16 = UInt16(message.byte0) << 8 | UInt16(message.byte1)
            let contactID: UInt16 = UInt16(message.byte2) << 8 | UInt16(message.byte3)
            let oldValue: UInt8 = message.byte4
            let newValue: UInt8 = message.byte5
            let time: UInt32 = UInt32((UInt16(message.byte6) << 8 | UInt16(message.byte7))) * 10 // ms
            let descriptor = CommandDescriptor(data: message.data, description: "\(cmd.toHex()) feedback: \(deviceID):\(contactID), from \(oldValue) to \(newValue), t = \(time)ms")
            return .feedback(deviceID: deviceID, contactID: contactID, oldValue: oldValue, newValue: newValue, time: time, descriptor: descriptor)
        }
        if cmd == 0x20 {
            let descriptor = CommandDescriptor(data: message.data, description: "\(cmd.toHex()) request locomotives")
            return .locomotives(descriptor: descriptor)
        }
        let description = "Unknown command \(cmd.toHex()), data: \(message.data as NSData)"
        return .unknown(command: message.command, descriptor: CommandDescriptor(data: message.data, description: description))
    }
}

extension MarklinCANMessage {
    
    static func from(command: Command) -> (MarklinCANMessage, Command.Priority) {
        switch(command) {
        case .go(priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.go(), priority)
            
        case .stop(priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.stop(), priority)
            
        case .emergencyStop(address: let address, decoderType: let decoderType, priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.emergencyStop(addr: address.actualAddress(for: decoderType)), priority)
            
        case .speed(address: let address, decoderType: let decoderType, value: let value, priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.speed(addr: address.actualAddress(for: decoderType), speed: value.value), priority)
            
        case .direction(address: let address, decoderType: let decoderType, direction: let direction, priority: let priority, descriptor: let descriptor):
            switch(direction) {
            case .forward:
                return (MarklinCANMessageFactory.forward(addr: address.actualAddress(for: decoderType)), priority)
            case .backward:
                return (MarklinCANMessageFactory.backward(addr: address.actualAddress(for: decoderType)), priority)
            case .unknown:
                fatalError("Unknown direction command \(String(describing: descriptor?.description))")
                break
            }
        case .queryDirection(address: let address, decoderType: let decoderType, priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.direction(addr: address.actualAddress(for: decoderType)), priority)
            
        case .turnout(address: let address, state: let state, power: let power, priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.accessory(addr: address.actualAddress, state: state, power: power), priority)
            
        case .feedback(deviceID: let deviceID, contactID: let contactID, oldValue: let oldValue, newValue: let newValue, time: let time, priority: let priority, descriptor: _):
            let time: UInt16 = UInt16(time / 10)
            return (MarklinCANMessageFactory.feedback(deviceID: deviceID, contactID: contactID, oldValue: oldValue, newValue: newValue, time: time), priority)
            
        case .locomotives(priority: let priority, descriptor: _):
            return (MarklinCANMessageFactory.locomotives(), priority)
            
        case .unknown(command: _, priority: _, descriptor: let descriptor):
            fatalError("Unknown command \(String(describing: descriptor?.description))")
        }
    }
}

extension CommandTurnoutAddress {
    
    var actualAddress: UInt32 {
        switch(`protocol`) {
        case .DCC:
            return 0x3800 + address - 1
        case .MM:
            return 0x3000 + address - 1
        case .none:
            return address
        }
    }
}
