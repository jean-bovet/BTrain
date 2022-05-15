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

extension XCTestCase {

    func waitForLeadingReservedAndSettled(train: Train) {
        wait(for: {
            train.leading.reservedAndSettled
        }, timeout: estimatedSettlingTime(for: train))
    }
    
    /// Returns the estimated time it will take to settle all the turnouts of the specified train.
    ///
    /// The time depends on the number of turnouts and the number of commands for each turnout
    /// necessary to change the state of the turnout.
    ///
    /// - Parameter train: The train
    /// - Returns: the estimated time to settle the leading turnouts of the train
    func estimatedSettlingTime(for train: Train) -> TimeInterval {
        var time: TimeInterval = 0
        for turnout in train.leading.turnouts {
            let numberOfCommands = turnout.requestedStateCommands(power: 1).count * 2
            time += Double(numberOfCommands) * LayoutCommandExecutor.turnoutDelay
        }
        return time * 1.5
    }
}

extension XCTestCase {
    
    func wait(for block: () -> Bool, timeout: TimeInterval) {
        let current = RunLoop.current
        let startTime = Date()
        while !block() {
            current.run(until: Date(timeIntervalSinceNow: 0.01))
            if Date().timeIntervalSince(startTime) >= timeout {
                XCTFail("Time out")
                break
            }
        }
    }

}

extension XCTestCase {
    
    func wait(for duration: TimeInterval) {
        let current = RunLoop.current
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < duration {
            current.run(until: Date(timeIntervalSinceNow: 0.250))
        }
    }
}
