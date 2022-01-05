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

class FeedbackTests: XCTestCase {

    func testCodable() throws {
        let f1 = Feedback("1", deviceID: 1, contactID: 2)
        f1.name = "F1"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(f1)

        let decoder = JSONDecoder()
        let f2 = try decoder.decode(Feedback.self, from: data)
        
        XCTAssertEqual(f1.id, f2.id)
        XCTAssertEqual(f1.name, f2.name)
        XCTAssertEqual(f1.deviceID, f2.deviceID)
        XCTAssertEqual(f1.contactID, f2.contactID)
    }

    func testFind() {
        let f1 = Feedback("1", deviceID: 1, contactID: 1)
        let f2 = Feedback("2", deviceID: 1, contactID: 2)
        let f3 = Feedback("3", deviceID: 2, contactID: 2)
        let f4 = Feedback("4", deviceID: 3, contactID: 2)

        let feedbacks = [f1, f2, f3, f4]
        
        XCTAssertEqual(feedbacks.find(deviceID: 1, contactID: 1), f1)
        XCTAssertEqual(feedbacks.find(deviceID: 1, contactID: 2), f2)
        XCTAssertEqual(feedbacks.find(deviceID: 2, contactID: 2), f3)
        XCTAssertEqual(feedbacks.find(deviceID: 3, contactID: 2), f4)
        XCTAssertNil(feedbacks.find(deviceID:0, contactID:0))
    }
}
