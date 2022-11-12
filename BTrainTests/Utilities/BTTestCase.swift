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

class BTTestCase: XCTestCase {
    
    /// Contains the key/value pairs of the UserDefaults before a test starts
    var backup = [String:Any]()
        
    /// Keep track of the current number of speed request change count when a test starts
    private var previousSpeedRequestCount: Int = 0
    
    /// Returns the maximum number of speed change requests that is expected to happen
    /// during the execution of each test. By default, this number is nil which disables that check.
    /// The goal is to ensure there is not a bug in the code that would cause an explosion of speed
    /// change requests.
    var speedChangeRequestCeiling: Int? {
        nil
    }
    
    override func setUp() {
        super.setUp()
        backup = UserDefaults.standard.dictionaryRepresentation()
        BaseTimeFactor = 0.0
        previousSpeedRequestCount = LocomotiveSpeedManager.globalRequestUUID
        LayoutController.memoryLeakCounter = 0
    }
    
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.setValuesForKeys(backup)
        BaseTimeFactor = 1.0
        
        let speedChangeCount = LocomotiveSpeedManager.globalRequestUUID - previousSpeedRequestCount
        print("Train Speed Change Count is \(LocomotiveSpeedManager.globalRequestUUID) total, \(speedChangeCount) for this test")
        if let speedChangeRequestCeiling = speedChangeRequestCeiling {
            XCTAssertLessThanOrEqual(speedChangeCount, speedChangeRequestCeiling)
        }
        
        XCTAssertEqual(LayoutController.memoryLeakCounter, 0, "LayoutController is leaking")
    }
    
    static func wait(for block: () -> Bool, timeout: TimeInterval) {
        let current = RunLoop.current
        let startTime = Date()
        while !block() {
            current.run(until: Date(timeIntervalSinceNow: 0.001))
            if Date().timeIntervalSince(startTime) >= timeout {
                XCTFail("Time out")
                break
            }
        }
    }

}
