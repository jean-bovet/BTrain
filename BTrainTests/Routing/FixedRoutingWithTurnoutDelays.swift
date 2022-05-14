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

/// Tests that take into account the fact that a turnout state actually changes with a delay in a physical layout. The train controller
/// needs to handle that delay appropriately, by braking or stopping the train until the turnouts are fully settled.
class FixedRoutingWithTurnoutDelays: XCTestCase {

    func testMoveInsideBlockWithTurnoutDelay() throws {
        let layout = LayoutLoop1().newLayout().removeTrainGeometry()
        let t0 = layout.turnout(named: "t0")
        t0.requestedState = .branchLeft
        layout.applyTurnoutState(turnout: t0)
        
        let delayedExecutor = DelayedCommandExecutor()
        delayedExecutor.pause()
        
        layout.executing = delayedExecutor
        
        let p = FixedRoutingTests.Package(layout: layout)
        try p.prepare(routeID: "r1", trainID: "1", fromBlockId: "b1")

        // t0 has still the state .branchLeft instead of the requested .straight
        try p.assert("r1: {r1{b1 🔴🚂1 ≏ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2)> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≏ }}")

        // The train will switch to managed scheduling but does not start yet because the turnout t0 hasn't settled.
        try p.start(expectedState: .stopped)

        // t0 has still the state .branchLeft instead of the requested .straight
        try p.assert("r1: {r1{b1 🔴🚂1 ≏ ≏ }} <r1<t0,l>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")

        // This will settle the turnout t0
        delayedExecutor.resume()
        p.layoutController.runControllers(.turnoutChanged)

        // And the train will restart because the leading turnouts are settled
        XCTAssertEqual(p.train.state, .running)
        
        try p.assert("r1: {r1{b1 🔵🚂1 ≏ ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≡ 🔵🚂1 ≏ }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≏ ≡ }}")
        try p.assert("r1: {r1{b1 ≏ ≡ 🔵🚂1 }} <r1<t0>> [r1[b2 ≏ ≏ ]] <t1(0,2)> [b3 ≏ ≏ ] <r1<t0(2,0)>> !{r1{b1 ≡ ≏ }}")
        
        // Pause again the turnout executor which will prevent the leading turnouts from settling
        delayedExecutor.pause()

        // The train will stop because the leading turnouts are not yet fully settled
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≡ 🟡🚂1 ≏ ]] <r1<t1(0,2),s>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≡ 🔴🚂1 ]] <r1<t1(0,2),s>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        
        // Resuming the executor which will settle the leading turnouts
        delayedExecutor.resume()

        // The train restarts because all the turnouts have settled
        try p.assert("r1: {b1 ≏ ≏ } <t0> [r1[b2 ≏ ≏ 🔵🚂1 ]] <r1<t1(0,2),l>> [r1[b3 ≏ ≏ ]] <t0(2,0)> !{b1 ≏ ≏ }")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1(0,2),l> [r1[b3 ≡ 🔵🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1(0,2),l> [r1[b3 ≏ 🔵🚂1 ≏ ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ ≏ }} <r1<t0,l>> [b2 ≏ ≏ ] <t1(0,2),l> [r1[b3 ≏ ≡ 🔵🚂1 ]] <r1<t0(2,0),l>> !{r1{b1 ≏ ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟡🚂1 ≡ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2),l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≡ 🟡🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 ≏ 🟡🚂1 ≏ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2),l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ 🟡🚂1 ≏ }}")
        try p.assert("r1: {r1{b1 🔴🚂1 ≡ ≏ }} <t0,l> [b2 ≏ ≏ ] <t1(0,2),l> [b3 ≏ ≏ ] <t0(2,0),l> !{r1{b1 ≏ ≡ 🔴🚂1 }}")
    }

    final class DelayedCommandExecutor: LayoutCommandExecuting {
        
        private var pauseExecution = false {
            didSet {
                if pauseExecution == false {
                    resumePausedTurnouts()
                }
            }
        }
        
        private var pausedTurnouts = [Turnout]()
        
        func pause() {
            pauseExecution = true
        }
        
        func resume() {
            pauseExecution = false
        }
        
        func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
            if pauseExecution {
                pausedTurnouts.append(turnout)
            } else {
                resumePausedTurnouts()
                turnout.actualState = turnout.requestedState
            }
            completion()
        }
        
        private func resumePausedTurnouts() {
            for pt in pausedTurnouts {
                pt.actualState = pt.requestedState
            }
            pausedTurnouts.removeAll()
        }
        
        func sendTrainDirection(train: Train, forward: Bool, completion: @escaping CompletionBlock) {
            completion()
        }
        
        func sendTrainSpeed(train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionBlock) {
            train.speed.actualSteps = train.speed.requestedSteps
            completion()
        }

    }
    
}
