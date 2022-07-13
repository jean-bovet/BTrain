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

class LayoutControllerTests: BTTestCase {

    func testTurnoutListener() throws {
        let layout = LayoutComplexLoop().newLayout()
        let interface = MarklinInterface()
        let c = LayoutController(layout: layout, switchboard: nil, interface: interface)
        c.registerForTurnoutChange()
        
        let t1 = layout.turnouts[0]
        t1.setActualState(value: 0, for: t1.address.actualAddress)
        XCTAssertEqual(t1.actualState, .branchLeft)

        let m = MarklinCANMessageFactory.accessory(addr: t1.address.actualAddress, state: 1, power: 1)
        interface.onMessage(msg: m)
        
        XCTAssertEqual(t1.actualState, .branchLeft)
        
        interface.onMessage(msg: m.ack)
        XCTAssertEqual(t1.actualState, .straight)
    }

}
