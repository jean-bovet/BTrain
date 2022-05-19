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

class LayoutYardRoutingTests: XCTestCase {
    
    /// Ensure turnouts are not activated unnecessarily when the blocks are reserved
    /// and re-reserved again.
    func testActivateTurnoutOnlyOnce() throws {
        let layout = LayoutYard().newLayout()
        let executor = CountingCommandExecutor()
        layout.executing = executor
        
        let p = FixedRoutingTests.Package(layout: layout)
        try p.prepare(routeID: "1", trainID: "0", fromBlockId: "A")
        try p.assert("1: {r0{A 🔴🚂0 ≏ ≏ }} [B ≏ ≏ ] <T1(0,2),s> <T2> <T3> [Z ≏ ≏ ] <T4(1,0)> <T5(1,0)> <T6(2,0),s> [D ≏ ≏ ] {E ≏ ≏ }")
        
        XCTAssertEqual(0, executor.turnouts.count)
        
        try p.start()
        
        XCTAssertEqual(3, executor.turnouts.count)
        
        executor.turnouts.removeAll()
        
        try p.assert("1: {r0{A 🔵🚂0 ≏ ≏ }} [r0[B ≏ ≏ ]] <r0<T1(0,2),r>> <r0<T2>> <r0<T3>> [r0[Z ≏ ≏ ]] <T4(1,0)> <T5(1,0)> <T6(2,0),s> [D ≏ ≏ ] {E ≏ ≏ }")

        XCTAssertEqual(0, executor.turnouts.count)

        try p.assert("1: {r0{A ≡ 🔵🚂0 ≏ }} [r0[B ≏ ≏ ]] <r0<T1(0,2),r>> <r0<T2>> <r0<T3>> [r0[Z ≏ ≏ ]] <T4(1,0)> <T5(1,0)> <T6(2,0),s> [D ≏ ≏ ] {E ≏ ≏ }")
        
        XCTAssertEqual(0, executor.turnouts.count)

        try p.assert("1: {r0{A ≏ ≡ 🔵🚂0 }} [r0[B ≏ ≏ ]] <r0<T1(0,2),r>> <r0<T2>> <r0<T3>> [r0[Z ≏ ≏ ]] <T4(1,0)> <T5(1,0)> <T6(2,0),s> [D ≏ ≏ ] {E ≏ ≏ }")
        
        XCTAssertEqual(0, executor.turnouts.count)
        
        try p.assert("1: {A ≏ ≏ } [r0[B ≡ 🔵🚂0 ≏ ]] <r0<T1(0,2),r>> <r0<T2>> <r0<T3>> [r0[Z ≏ ≏ ]] <r0<T4(1,0)>> <r0<T5(1,0)>> <r0<T6(2,0),l>> [r0[D ≏ ≏ ]] {E ≏ ≏ }")
        XCTAssertEqual(3, executor.turnouts.count)
        
    }
    
    final class CountingCommandExecutor: LayoutCommandExecuting {
        
        var turnouts = [Turnout]()
        
        func scheduleRestartTimer(train: Train) {
            
        }
        
        func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
            turnouts.append(turnout)
            turnout.actualState = turnout.requestedState
            completion()
        }
        
        func sendTrainDirection(train: Train, forward: Bool, completion: @escaping CompletionBlock) {
            completion()
        }
        
        func sendTrainSpeed(train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock) {
            train.speed.actualSteps = train.speed.requestedSteps
            completion(true)
        }
        
    }

}
