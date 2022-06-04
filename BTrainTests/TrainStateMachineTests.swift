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

    func testLayoutEventFeedback() {
        let train = MockTrain()
        let sm = TrainStateMachine()

        XCTAssertEqual(sm.handle(layoutEvent: .feedback, train: train), .reservedBlocksChanged(train))
        
        XCTAssertEqual(sm.handle(layoutEvent: .speed, train: train), nil)
        
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(sm.handle(layoutEvent: .turnout, train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 1)
    }
    
    func testTrainEvent() {
        let train = MockTrain()
        let sm = TrainStateMachine()

        let anotherTrain = MockTrain()
        
        XCTAssertEqual(sm.handle(trainEvent: .position(train), train: train), .reservedBlocksChanged(train))
        XCTAssertEqual(sm.handle(trainEvent: .position(anotherTrain), train: train), nil)
        
        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(sm.handle(trainEvent: .reservedBlocksChanged(train), train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 1)

        XCTAssertEqual(sm.handle(trainEvent: .reservedBlocksChanged(anotherTrain), train: train), .reservedBlocksChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 1)
    }
    
    func testTrainStart() {
        let train = MockTrain()
        let sm = TrainStateMachine()
                
        XCTAssertEqual(train.state, .stopped)
        train.isManagedSchedule = true
        
        train.onUpdateREservedBlocks = {
            train.reservedBlocksLengthEnoughToRun = true
            return true
        }
        XCTAssertEqual(sm.handle(trainEvent: .scheduling(train), train: train), .reservedBlocksChanged(train))
        
        XCTAssertEqual(train.state, .running)
    }
    
    func testTrainStart2() {
        let t1 = MockTrain()
        let t2 = MockTrain()
        let sm = TrainStateMachine()
                
        XCTAssertEqual(t1.state, .stopped)
        XCTAssertEqual(t2.state, .stopped)
        
        t1.isManagedSchedule = true
        
        t1.onUpdateREservedBlocks = {
            if !t1.reservedBlocksLengthEnoughToRun {
                t1.reservedBlocksLengthEnoughToRun = true
                return true
            } else {
                return false
            }
        }
        
        sm.handle(layoutEvent: nil, trainEvent: .scheduling(t1), trains: [t1, t2])
        
        XCTAssertEqual(t1.state, .running)
        XCTAssertEqual(t2.state, .stopped)
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

final class MockTrain: TrainModel {

    var id: String = UUID().uuidString
    
    var state: TrainStateMachine.TrainState = .stopped
    
    var speed: Double = 0
        
    var isManagedSchedule: Bool = true
    
    var stopManagedSchedule: Bool = false

    var reservedBlocksLengthEnoughToRun: Bool = false
    
    var brakeFeedbackActivated: Bool = false
    
    var stopFeedbackActivated: Bool = false
    
    var atEndOfRoute: Bool = false
    
    var locatedInStationBlock: Bool = false
    
    func updatePosition() -> Bool {
        return true
    }
    
    func updateSpeed() -> Bool {
        return true
    }
    
    func updateReservedBlocksLength() -> Bool {
        return true
    }        

    func updateOccupiedAndReservedBlocks() -> Bool {
        return true
    }
    
    typealias OnUpdateREservedBlocks = () -> Bool
    
    var onUpdateREservedBlocks: OnUpdateREservedBlocks?
    
    func updateReservedBlocks() -> Bool {
        return onUpdateREservedBlocks?() ?? true
    }
    
    var adjustSpeedCount = 0
    
    func adjustSpeed() {
        adjustSpeedCount += 1
    }
    
}
