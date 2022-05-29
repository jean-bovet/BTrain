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

struct MarklinCANMessageFactory {
    
    static let hash: UInt16 = 0xbf46

    public static func go() -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x00,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x05,
                                        byte0: 0x00,
                                        byte1: 0x00,
                                        byte2: 0x00,
                                        byte3: 0x00,
                                        byte4: 0x01, // ON
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }
    
    public static func stop() -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x00,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x05,
                                        byte0: 0x00,
                                        byte1: 0x00,
                                        byte2: 0x00,
                                        byte3: 0x00,
                                        byte4: 0x00, // OFF
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }

    public static func emergencyStop(addr: UInt32) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x00,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x05,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: 0x03, // Sub-command
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message

    }

    public static func speed(addr: UInt32, speed: UInt16) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x04,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x06,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: UInt8((speed >> 8) & 0xFF), // speed high
                                        byte5: UInt8((speed >> 0) & 0xFF), // speed low
                                        byte6: 0, // not used
                                        byte7: 0 // not used
        )
        return message
    }
    
    // 00 0a bf 46 05 00 00 40 09 01 00 00 00 // forward
    public static func forward(addr: UInt32) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x05,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x05,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: 0x01, // forward
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }

    // 00 0a bf 46 05 00 00 40 09 02 00 00 00 // backward
    public static func backward(addr: UInt32) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x05,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x05,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: 0x02, // backward
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }

    // Request the direction of a specific locomotive
    public static func queryDirection(addr: UInt32) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x05,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x04,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: 0x00,
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }

    // Response to the direction request above
    public static func queryDirectionResponse(addr: UInt32, direction: UInt8) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x05,
                                        resp: 1,
                                        hash: hash,
                                        dlc: 0x04,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: direction,
                                        byte5: 0x00,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }

    public static func accessory(addr: UInt32, state: UInt8, power: UInt8) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x0B,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x06,
                                        byte0: UInt8((addr >> 24) & 0xFF),
                                        byte1: UInt8((addr >> 16) & 0xFF),
                                        byte2: UInt8((addr >> 8) & 0xFF),
                                        byte3: UInt8((addr >> 0) & 0xFF),
                                        byte4: state & 0xFF,
                                        byte5: power & 0xFF,
                                        byte6: 0x00,
                                        byte7: 0x00
        )
        return message
    }
    
    public static func feedback(deviceID: UInt16, contactID: UInt16, oldValue: UInt8, newValue: UInt8, time: UInt16) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x11,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x08,
                                        byte0: UInt8((deviceID >> 8) & 0xFF),
                                        byte1: UInt8((deviceID >> 0) & 0xFF),
                                        byte2: UInt8((contactID >> 8) & 0xFF),
                                        byte3: UInt8((contactID >> 0) & 0xFF),
                                        byte4: oldValue & 0xFF,
                                        byte5: newValue & 0xFF,
                                        byte6: UInt8((time >> 8) & 0xFF),
                                        byte7: UInt8((time >> 0) & 0xFF)
        )
        return message
    }

    /*
     
     0000   00 1f b2 05 63 e5 50 ed 3c 12 33 23 08 00 45 00   ....c.P.<.3#..E.
     0010   00 41 00 00 40 00 40 06 0d 16 c0 a8 56 20 c0 a8   .A..@.@.....V ..
     0020   56 30 d9 8b 3d 73 e4 89 71 bb ec 11 54 a1 80 18   V0..=s..q...T...
     0030   08 02 dd e7 00 00 01 01 08 0a 6c d6 42 45 00 01   ..........l.BE..
     0040   5b aa 00 40 bf 46 08 6c 6f 6b 73 00 00 00 00      [..@.F.loks....
     
     */
    public static func locomotives() -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x20,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x08,
                                        byte0: UInt8(Character("l").asciiValue! & 0xFF),
                                        byte1: UInt8(Character("o").asciiValue! & 0xFF),
                                        byte2: UInt8(Character("k").asciiValue! & 0xFF),
                                        byte3: UInt8(Character("s").asciiValue! & 0xFF),
                                        byte4: 0,
                                        byte5: 0,
                                        byte6: 0,
                                        byte7: 0
        )
        return message
    }

    public static func configData(length: UInt32) -> MarklinCANMessage {
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x21,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x06,
                                        byte0: UInt8((length >> 24) & 0xFF),
                                        byte1: UInt8((length >> 16) & 0xFF),
                                        byte2: UInt8((length >> 8) & 0xFF),
                                        byte3: UInt8((length >> 0) & 0xFF),
                                        byte4: 0,
                                        byte5: 0,
                                        byte6: 0,
                                        byte7: 0
        )
        return message
    }

    // Returns a CAN message with configuration data, up to 8 bytes maximum at a time.
    // If bytes is less than 8 bytes, the bytes are padded with 0x00
    public static func configData(bytes: [UInt8]) -> MarklinCANMessage {
        assert(bytes.count <= 8, "No more than 8 bytes of data can be specified at one time")
        let message = MarklinCANMessage(prio: 0,
                                        command: 0x21,
                                        resp: 0,
                                        hash: hash,
                                        dlc: 0x08,
                                        byte0: bytes.safeValue(at: 0) ?? 0,
                                        byte1: bytes.safeValue(at: 1) ?? 0,
                                        byte2: bytes.safeValue(at: 2) ?? 0,
                                        byte3: bytes.safeValue(at: 3) ?? 0,
                                        byte4: bytes.safeValue(at: 4) ?? 0,
                                        byte5: bytes.safeValue(at: 5) ?? 0,
                                        byte6: bytes.safeValue(at: 6) ?? 0,
                                        byte7: bytes.safeValue(at: 7) ?? 0
        )
        return message
    }

}

extension Array where Element == UInt8 {
    
    func safeValue(at index: Int) -> Element? {
        if index < count {
            return self[index]
        } else {
            return nil
        }
    }
}
