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

class TrainInertiaTests: XCTestCase {

    func testAcceleration() {
        let t = Train()
        let ic = TrainInertiaController(train: t)
        
        t.speed.steps = SpeedStep(value: 20)
        assertChangeSpeed(from: 0, to: 20, [4, 8, 12, 16, 20], ic)

        t.speed = .init(steps: SpeedStep(value: 13), decoderType: .DCC)
        assertChangeSpeed(from: 20, to: 13, [16, 13], ic)
        
        t.speed = .init(steps: SpeedStep(value: 14), decoderType: .DCC)
        assertChangeSpeed(from: 13, to: 14, [14], ic)

        t.speed = .init(steps: SpeedStep(value: 13), decoderType: .DCC)
        assertChangeSpeed(from: 14, to: 13, [13], ic)
        
        t.speed = .init(steps: SpeedStep(value: 0), decoderType: .DCC)
        assertChangeSpeed(from: 13, to: 0, [9, 5, 1, 0], ic)
    }
    
    private func assertChangeSpeed(from fromSteps: UInt16, to steps: UInt16, _ expectedSteps: [UInt16], _ ic: TrainInertiaController) {
        XCTAssertEqual(ic.actual.value, fromSteps)
        
        var expectedStepIndex = 0
        ic.changeSpeed(to: SpeedStep(value: steps)) { actualSteps, finished in
            XCTAssertEqual(actualSteps.value, expectedSteps[expectedStepIndex])
            expectedStepIndex += 1
        }
        
        wait(for: {
            ic.desired.value == steps
        }, timeout: 0.1)
        
        wait(for: {
            ic.actual.value == steps
        }, timeout: ic.duration)

        XCTAssertEqual(expectedStepIndex, expectedSteps.count)
    }
}

private extension TrainInertiaController {
    var duration: TimeInterval {
        ceil(abs(Double(desired.value) - Double(actual.value)) / Double(stepIncrement)) * stepDelay * 2
    }
}
