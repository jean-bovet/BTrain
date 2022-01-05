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

class CommandTests: XCTestCase {

    func testCommandFeedback() throws {
        let c1 = CommandFeedback(deviceID: 0, contactID: 0, value: 2)
        let c2 = CommandFeedback(deviceID: 0, contactID: 1, value: 2)
        let c3 = CommandFeedback(deviceID: 0, contactID: 0, value: 3)
        let c4 = CommandFeedback(deviceID: 1, contactID: 0, value: 2)
        XCTAssertEqual(c1, c1)
        XCTAssertEqual(c1, c3)
        XCTAssertNotEqual(c1, c2)
        XCTAssertNotEqual(c1, c4)
    }

}
