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

import XCTest
@testable import BTrain

class CANMessageTests: BTTestCase {

    func testEnable() {
        assert(msg: MarklinCANMessageFactory.go(),
               byteArray: [ 0x00, 0x00, 0xbf, 0x46, 0x05, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00 ],
               description: "0x00 System Go - cmd")
    }

    func testDisable() {
        assert(msg: MarklinCANMessageFactory.stop(),
               byteArray: [ 0x00, 0x00, 0xbf, 0x46, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ],
               description: "0x00 System Stop - cmd")
    }

    func testSpeed() {
        assert(msg: MarklinCANMessageFactory.speed(addr: 0x4009, speed: 113),
               byteArray: [ 0x00, 0x08, 0xbf, 0x46, 0x06, 0x00, 0x00, 0x40, 0x09, 0x00, 0x71, 0x00, 0x00 ],
               description: "0x04 speed 113 for 0x4009 - cmd")
    }

    func testForward() {
        assert(msg: MarklinCANMessageFactory.forward(addr: 0x4009),
               byteArray: [ 0x00, 0x0A, 0xbf, 0x46, 0x05, 0x00, 0x00, 0x40, 0x09, 0x01, 0x00, 0x00, 0x00 ],
               description: "0x05 forward for 0x4009 - cmd")
    }

    func testBackward() {
        assert(msg: MarklinCANMessageFactory.backward(addr: 0x4009),
               byteArray: [ 0x00, 0x0A, 0xbf, 0x46, 0x05, 0x00, 0x00, 0x40, 0x09, 0x02, 0x00, 0x00, 0x00 ],
               description: "0x05 backward for 0x4009 - cmd")
    }

    func testAccessory() {
        assert(msg: MarklinCANMessageFactory.accessory(addr: 0x4009, state: 0x2, power: 0x1),
               byteArray: [ 0x00, 0x16, 0xbf, 0x46, 0x06, 0x00, 0x00, 0x40, 0x09, 0x02, 0x01, 0x00, 0x00 ],
               description: "0x0B accessory 2-1 for 0x4009 - cmd")
    }

    func testFeedback1() {
        let (msg, _) = MarklinCANMessage.from(command: MarklinTestMessageFactory.feedback1())!
        assert(msg: msg,
               byteArray: MarklinTestMessageFactory.feedback1ByteArray,
               description: "0x11 feedback: 1:14, from 0 to 1, t = 655350ms - cmd")
    }

    func testFeedback2() {
        let (msg, _) = MarklinCANMessage.from(command: MarklinTestMessageFactory.feedback2())!
        assert(msg: msg,
               byteArray: MarklinTestMessageFactory.feedback2ByteArray,
               description: "0x11 feedback: 1:16, from 1 to 0, t = 29100ms - cmd")
    }

    func testUnknown() {
        UserDefaults.standard.set(true, forKey: SettingsKeys.logUnknownMessages)
        let byteArray: [UInt8] = [ 0x00, 0x20, 0x93, 0x70, 0x08, 0x00, 0x01, 0x00, 0x0e, 0x00, 0x01, 0xff, 0xff ]
        let msg = MarklinCANMessage.decode(from: byteArray)
        let string = MarklinCANMessagePrinter.description(message: msg)
        XCTAssertEqual(string, "Unknown command 0x10, data: {length = 13, bytes = 0x00209370080001000e0001ffff}")
    }

    func assert(msg: MarklinCANMessage, byteArray: [UInt8], description: String) {
        XCTAssertEqual(MarklinCANMessage.decode(from: msg.bytes), msg)

        XCTAssertEqual(msg.bytes, byteArray, "\(msg.data as NSData)")
        
        let string = MarklinCANMessagePrinter.description(message: msg)
        XCTAssertEqual(description, string)
    }
    
    func testEncodeAndDecode() {
        let msg = MarklinCANMessage(prio: 0xF,
                                           command: 0xFF,
                                           resp: 1,
                                           hash: 0xbf46,
                                           dlc: 0x06,
                                           byte0: 0x00,
                                           byte1: 0x01,
                                           byte2: 0x02,
                                           byte3: 0x03,
                                           byte4: 0x04,
                                           byte5: 0x05,
                                           byte6: 0x06,
                                           byte7: 0x07)
        XCTAssertEqual(msg, MarklinCANMessage.decode(from: msg.bytes))

        let byteArray: [UInt8] = [ 0x1F, 0xFF, 0xbf, 0x46, 0x06, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 ]
        XCTAssertEqual(byteArray, msg.bytes)
    }

}
