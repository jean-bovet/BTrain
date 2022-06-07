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

class TrainStateMachineTests: XCTestCase {

    var train: MockTrainController!
    let sm = TrainStateMachine()

    override func setUp() {
        super.setUp()
        train = MockTrainController()
    }
    
    // MARK: - Layout Events

    func testLayoutEventFeedback() {
        let f1 = Feedback("f1")
        
        train.onUpdatePosition = { f in return f == f1 }
        train.onUpdateOccupiedAndReservedBlocks = { return true }
        XCTAssertEqual(sm.handle(layoutEvent: .feedback(f1), train: train), .reservedBlocksChanged(train))
        
        train.onUpdatePosition = { f in return false }
        train.onUpdateOccupiedAndReservedBlocks = { return true }
        XCTAssertEqual(sm.handle(layoutEvent: .feedback(f1), train: train), nil)
        
        train.onUpdatePosition = { f in return f == f1 }
        train.onUpdateOccupiedAndReservedBlocks = { return false }
        XCTAssertEqual(sm.handle(layoutEvent: .feedback(f1), train: train), nil)
        
        train.onUpdatePosition = { f in return false }
        train.onUpdateOccupiedAndReservedBlocks = { return false }
        XCTAssertEqual(sm.handle(layoutEvent: .feedback(f1), train: train), nil)
    }
    
    func testLayoutEventSpeed() {
        var speedUpdated = false
        train.onUpdateSpeed = {
            speedUpdated = true
            return true
        }
        XCTAssertEqual(sm.handle(layoutEvent: .speed, train: train), nil)
        XCTAssertTrue(speedUpdated)
    }

    func testLayoutEventTurnout() {
        let t1 = Turnout(name: "t1")
        train.state = .running
        
        XCTAssertEqual(train.adjustSpeedCount, 0)

        train.onUpdateReservedBlocksSettledLength = { t in
            return false
        }
        XCTAssertEqual(sm.handle(layoutEvent: .turnout(t1), train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 0)
        
        train.onUpdateReservedBlocksSettledLength = { t in
            return t == t1
        }
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(sm.handle(layoutEvent: .turnout(t1), train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 1)
    }

    // MARK: - Train Events
    
    func testEventPosition() {
        let anotherTrain = MockTrainController()
        
        train.onUpdatePosition = { f in return true }
        train.onUpdateOccupiedAndReservedBlocks = { return true }
        XCTAssertEqual(sm.handle(trainEvent: .position(train), train: train), .reservedBlocksChanged(train))
        
        XCTAssertEqual(sm.handle(trainEvent: .position(anotherTrain), train: train), nil)
    }
    
    func testEventReservedBlocksChanged() {
        let anotherTrain = MockTrainController()
        train.state = .running // because adjustSpeed() is only called when the train is not stopped
                
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(sm.handle(trainEvent: .reservedBlocksChanged(train), train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 1)

        train.onUpdateReservedBlocks = { return true }
        XCTAssertEqual(sm.handle(trainEvent: .reservedBlocksChanged(anotherTrain), train: train), .reservedBlocksChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 1)
    }

    func testTrainStart() {
        XCTAssertEqual(train.state, .stopped)
        train.isManagedSchedule = true
        
        train.onUpdateReservedBlocks = {
            self.train.reservedBlocksLengthEnoughToRun = false
            return true
        }
        handle(trainEvent: .scheduling(train), train: train, handledEvents: [.scheduling(train), .reservedBlocksChanged(train)])

        XCTAssertEqual(train.state, .stopped)
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(train.speed, 0)

        train.onUpdateReservedBlocks = {
            self.train.reservedBlocksLengthEnoughToRun = true
            return true
        }
        handle(trainEvent: .scheduling(train), train: train, handledEvents: [.scheduling(train), .reservedBlocksChanged(train)])

        XCTAssertEqual(train.state, .running)
        XCTAssertEqual(train.adjustSpeedCount, 1)
        XCTAssertEqual(train.speed, LayoutFactory.DefaultMaximumSpeed)
    }
    
    func testTrainStart2() {
        let t1 = MockTrainController()
        let t2 = MockTrainController()
                
        XCTAssertEqual(t1.state, .stopped)
        XCTAssertEqual(t2.state, .stopped)
        
        t1.isManagedSchedule = true
        
        t1.onUpdateReservedBlocks = {
            if !t1.reservedBlocksLengthEnoughToRun {
                t1.reservedBlocksLengthEnoughToRun = true
                return true
            } else {
                return false
            }
        }
        
        handle(trainEvent: .scheduling(t1), trains: [t1, t2], handledEvents: [.scheduling(t1), .reservedBlocksChanged(t1)])
        
        XCTAssertEqual(t1.state, .running)
        XCTAssertEqual(t1.updateReservedBlocksInvocationCount, 1)

        XCTAssertEqual(t2.state, .stopped)
        XCTAssertEqual(t2.updateReservedBlocksInvocationCount, 1)
    }
    
    func testTrainMove() {
        train.isManagedSchedule = true
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed
        
        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in return f == f1 }
        train.onUpdateOccupiedAndReservedBlocks = { return true }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        
        XCTAssertEqual(train.updatePositionInvocationCount, 1)
        XCTAssertEqual(train.state, .running)

        // f2 does not trigger a change in position for the train, which translates into no handled events for the train.
        let f2 = Feedback("f2")
        handle(layoutEvent: .feedback(f2), train: train, handledEvents: [])
        
        XCTAssertEqual(train.updatePositionInvocationCount, 2)
        XCTAssertEqual(train.state, .running)
    }
    
    func testTrainMoveAndBrakeBecauseSettledDistance() {
        train.isManagedSchedule = true
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed
        
        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in return f == f1 }
        train.onUpdateOccupiedAndReservedBlocks = {
            self.train.reservedBlocksLengthEnoughToRun = false
            return true
        }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        
        XCTAssertEqual(train.state, .braking)
        XCTAssertEqual(train.updatePositionInvocationCount, 1)
        XCTAssertEqual(train.speed, LayoutFactory.DefaultMaximumSpeed)
    }

}

extension TrainStateMachineTests {
    
    func handle(layoutEvent: TrainStateMachine.LayoutEvent? = nil, trainEvent: TrainStateMachine.TrainEvent? = nil, train: TrainControlling, handledEvents: [TrainStateMachine.TrainEvent]) {
        handle(layoutEvent: layoutEvent, trainEvent: trainEvent, trains: [train], handledEvents: handledEvents)
    }
    
    func handle(layoutEvent: TrainStateMachine.LayoutEvent? = nil, trainEvent: TrainStateMachine.TrainEvent? = nil, trains: [TrainControlling], handledEvents: [TrainStateMachine.TrainEvent]) {
        var actualHandledEvents: [TrainStateMachine.TrainEvent]? = [TrainStateMachine.TrainEvent]()
        sm.handle(layoutEvent: layoutEvent, trainEvent: trainEvent, trains: trains, handledTrainEvents: &actualHandledEvents)
        XCTAssertEqual(actualHandledEvents, handledEvents)
    }

}

extension TrainStateMachine.TrainEvent: Equatable {
    
    static public func == (lhs: TrainStateMachine.TrainEvent, rhs: TrainStateMachine.TrainEvent) -> Bool {
        switch(lhs, rhs) {
        case (.position(let t1), .position(let t2)): return t1.id == t2.id
        case (.speed(let t1), .speed(let t2)): return t1.id == t2.id
        case (.scheduling(let t1), .scheduling(let t2)): return t1.id == t2.id
        case (.restartTimerFired(let t1), .restartTimerFired(let t2)): return t1.id == t2.id
        case (.reservedBlocksChanged(let t1), .reservedBlocksChanged(let t2)): return t1.id == t2.id
        case (.reservedBlocksSettledLengthChanged(let t1), .reservedBlocksSettledLengthChanged(let t2)): return t1.id == t2.id
        default:
            return false
        }
    }

}
