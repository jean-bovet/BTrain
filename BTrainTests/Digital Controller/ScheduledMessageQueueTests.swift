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

class ScheduledMessageQueueTests: XCTestCase {

    func testDelay() throws {
        let queue = ScheduledMessageQueue()
        let expectation = XCTestExpectation.init(description: "scheduled")
        let startTime = Date()
        queue.schedule(priority: false) { completion in
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startTime), queue.delay)
            expectation.fulfill()
            completion()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testPriorityNormal() throws {
        let queue = ScheduledMessageQueue()
        let normalExpectation = XCTestExpectation.init(description: "normal")
        let normalExpectation2 = XCTestExpectation.init(description: "normal2")
        let startTime = Date()
        var normalExecutedFirst = false
        queue.schedule(priority: false) { completion in
            XCTAssertFalse(normalExecutedFirst)
            normalExecutedFirst = true
            
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startTime), queue.delay)
            normalExpectation.fulfill()
            completion()
        }
        queue.schedule(priority: false) { completion in
            XCTAssertTrue(normalExecutedFirst)
            normalExecutedFirst = false
            
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startTime), queue.delay)
            normalExpectation2.fulfill()
            completion()
        }
        wait(for: [normalExpectation, normalExpectation2], timeout: 1)
    }

    func testPriorityHigh() throws {
        let queue = ScheduledMessageQueue()
        let normalExpectation = XCTestExpectation.init(description: "normal")
        let highExpectation = XCTestExpectation.init(description: "high")
        let startTime = Date()
        var highPriorityMessageExecuted = false
        queue.schedule(priority: false) { completion in
            XCTAssertTrue(highPriorityMessageExecuted)
            highPriorityMessageExecuted = false
            
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startTime), queue.delay)
            normalExpectation.fulfill()
            completion()
        }
        queue.schedule(priority: true) { completion in
            XCTAssertFalse(highPriorityMessageExecuted)
            highPriorityMessageExecuted = true
            
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(startTime), queue.delay)
            highExpectation.fulfill()
            completion()
        }
        wait(for: [normalExpectation, highExpectation], timeout: 1)
    }

}
