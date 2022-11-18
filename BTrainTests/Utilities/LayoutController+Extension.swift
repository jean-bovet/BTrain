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

@testable import BTrain

extension LayoutController {
    /// This method returns when all the trains (and locomotives) have settled.
    ///
    /// Specifically, a train is considered settled when:
    /// - It's leading blocks and turnouts are settled
    /// A locomotive is considered settled when:
    /// - It's requested speed is equal to its actual speed
    func waitUntilSettled() {
        var drain = true
        while drain {
            drain = false
            for loc in layout.locomotives.elements {
                if loc.speed.requestedSteps != loc.speed.actualSteps {
                    // Speed is not yet settled
                    drain = true
                }
            }
            for train in layout.trains.elements {
                if !train.leading.emptyOrSettled, !train.leading.reservedAndSettled {
                    // Leading blocks and turnouts are not yet settled
                    drain = true
                }
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.001))
        }
    }
}
