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

final class MarklinTestMessageFactory {
    static let feedback1ByteArray: [UInt8] = [0x00, 0x22, 0xBF, 0x46, 0x08, 0x00, 0x01, 0x00, 0x0E, 0x00, 0x01, 0xFF, 0xFF]
    static let feedback2ByteArray: [UInt8] = [0x00, 0x22, 0xBF, 0x46, 0x08, 0x00, 0x01, 0x00, 0x10, 0x01, 0x00, 0x0B, 0x5E]

    static func feedback1() -> Command {
        let msg = MarklinCANMessage.decode(from: feedback1ByteArray)
        return Command.from(message: msg)
    }

    static func feedback2() -> Command {
        let msg = MarklinCANMessage.decode(from: feedback2ByteArray)
        return Command.from(message: msg)
    }

    static func feedbackRandom() -> Command {
        let byteArray: [UInt8] = [0x00, 0x23, 0x93, 0x70, 0x08,
                                  0x00, UInt8.random(in: 0 ..< 0x02),
                                  0x00, UInt8.random(in: 1 ..< 0x08),
                                  0x00, Bool.random() ? 0x01 : 0x00,
                                  UInt8.random(in: 0 ..< 0xFF), UInt8.random(in: 1 ..< 0xFF)]
        let msg = MarklinCANMessage.decode(from: byteArray)
        return Command.from(message: msg)
    }
}
