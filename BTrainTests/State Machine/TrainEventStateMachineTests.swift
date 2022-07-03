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

class TrainEventStateMachineTests: XCTestCase {
    
    var train: MockTrainController!
    let tsm = TrainEventStateMachine()
    
    override func setUp() {
        super.setUp()
        train = MockTrainController(route: Route(uuid: "fixed-test", mode: .fixed))
    }
    
    func testEventPosition() {
        let anotherTrain = MockTrainController(route: train.route)
        
        train.onUpdateOccupiedAndReservedBlocks = { return true }
        XCTAssertEqual(tsm.handle(trainEvent: .position(train), train: train), .reservedBlocksChanged(train))
        
        XCTAssertEqual(tsm.handle(trainEvent: .position(anotherTrain), train: train), nil)
    }
    
    func testEventReservedBlocksChanged() {
        let anotherTrain = MockTrainController(route: train.route)
        train.state = .running // because adjustSpeed() is only called when the train is not stopped
                
        train.onReservedBlocksLengthEnough = { speed in return false }
        train.brakeFeedbackActivated = true
        
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(tsm.handle(trainEvent: .reservedBlocksChanged(train), train: train), .stateChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 1)

        train.onUpdateReservedBlocks = { return true }
        XCTAssertEqual(tsm.handle(trainEvent: .reservedBlocksChanged(anotherTrain), train: train), .reservedBlocksChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 1)
    }

}

extension StateMachine.TrainEvent: Equatable {
    
    static public func == (lhs: StateMachine.TrainEvent, rhs: StateMachine.TrainEvent) -> Bool {
        switch(lhs, rhs) {
        case (.position(let t1), .position(let t2)): return t1.id == t2.id
        case (.speed(let t1), .speed(let t2)): return t1.id == t2.id
        case (.modeChanged(let t1), .modeChanged(let t2)): return t1.id == t2.id
        case (.stateChanged(let t1), .stateChanged(let t2)): return t1.id == t2.id
        case (.restartTimerFired(let t1), .restartTimerFired(let t2)): return t1.id == t2.id
        case (.reservedBlocksChanged(let t1), .reservedBlocksChanged(let t2)): return t1.id == t2.id
        case (.reservedBlocksSettledLengthChanged(let t1), .reservedBlocksSettledLengthChanged(let t2)): return t1.id == t2.id
        default:
            return false
        }
    }

}
