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

struct MarklinCANMessage: Equatable, Hashable {
    
    static let messageLength = 13
    
    let prio: UInt8
    let command: UInt8
    let resp: UInt8
    let hash: UInt16
    let dlc: UInt8
    let byte0: UInt8
    let byte1: UInt8
    let byte2: UInt8
    let byte3: UInt8
    let byte4: UInt8
    let byte5: UInt8
    let byte6: UInt8
    let byte7: UInt8
}

// MARK: Utility

extension MarklinCANMessage {
    
    // Example: 00 08 bf 46 06 00 00 40 09 00 71 00 00
    //      Filler   | 2+2bits | 8 bits command | 1 bit rep | 16 bits hash | DLC 4 bit | Byte 0 | .. Byte 7
    // Bin: 000        1111      0100 0100         0
    // Bin: 0001 1110 1000 1000                    [Hash]
    //         |   ||        ||
    public static func decode(from bytes: [UInt8]) -> MarklinCANMessage {
        let prio: UInt8 = (bytes[0] >> 1) & 0x0F
        let command: UInt8 = ((bytes[0] << 7) & 0xFF) | ((bytes[1] >> 1) & 0xFF)
        let resp: UInt8 = (bytes[1] & 0x01)
        let hash: UInt16 = UInt16(bytes[2]) << 8 | UInt16(bytes[3])
        let dlc: UInt8 = bytes[4]
        let byte0: UInt8 = bytes[5]
        let byte1: UInt8 = bytes[6]
        let byte2: UInt8 = bytes[7]
        let byte3: UInt8 = bytes[8]
        let byte4: UInt8 = bytes[9]
        let byte5: UInt8 = bytes[10]
        let byte6: UInt8 = bytes[11]
        let byte7: UInt8 = bytes[12]
        return MarklinCANMessage(prio: prio, command: command, resp: resp, hash: hash, dlc: dlc, byte0: byte0, byte1: byte1, byte2: byte2, byte3: byte3, byte4: byte4, byte5: byte5, byte6: byte6, byte7: byte7)
    }
    
    var bytes: [UInt8] {
        var byteArray = [UInt8]()

        byteArray.append((prio << 1) & 0xFF | (command >> 7) & 0xFF)   // Filler + priority + command bit 7
        byteArray.append((command << 1) & 0xFF | (resp & 0x01))   // Command bit 0 to 6 + resp bit
        byteArray.append(UInt8((hash >> 8) & 0xFF)) // hashbyte1
        byteArray.append(UInt8((hash >> 0) & 0xFF)) // hashbyte2
        byteArray.append(dlc) // DLC (Data Length Code)

        byteArray.append(byte0)
        byteArray.append(byte1)
        byteArray.append(byte2)
        byteArray.append(byte3)
        byteArray.append(byte4)
        byteArray.append(byte5)
        byteArray.append(byte6)
        byteArray.append(byte7)

        return byteArray
    }
            
    var data: Data {
        let bytes = bytes
        return Data(bytes: bytes, count: bytes.count)
    }
}
