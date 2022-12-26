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

@testable import BTrain
import XCTest

class TrainEventStateMachineTests: XCTestCase {
    var train: MockTrainController!
    let tsm = TrainEventStateMachine()

    override func setUp() {
        super.setUp()
        train = MockTrainController(route: Route(uuid: "fixed-test", mode: .fixed))
    }

    func testEventPosition() throws {
        let anotherTrain = MockTrainController(route: train.route)

        train.onUpdateOccupiedAndReservedBlocks = { true }
        XCTAssertEqual(try tsm.handle(trainEvent: .position(train), train: train), .reservedBlocksChanged(train))

        train.onUpdateOccupiedAndReservedBlocks = { false }
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .position(train), train: train), nil)

        train.state = .running
        train.mode = .stopManaged
        train.stopFeedbackActivated = true
        XCTAssertEqual(try tsm.handle(trainEvent: .position(train), train: train), .stateChanged(train))

        XCTAssertEqual(try tsm.handle(trainEvent: .position(anotherTrain), train: train), nil)
    }

    func testEventReservedBlocksChanged() throws {
        let anotherTrain = MockTrainController(route: train.route)
        train.mode = .managed
        train.state = .running // because adjustSpeed() is only called when the train is not stopped

        train.onReservedBlocksLengthEnough = { _ in false }
        train.brakeFeedbackActivated = true

        XCTAssertEqual(train.adjustSpeedCount, 0)
        XCTAssertEqual(try tsm.handle(trainEvent: .reservedBlocksChanged(train), train: train), .stateChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 1)

        train.onUpdateReservedBlocks = { true }
        XCTAssertEqual(try tsm.handle(trainEvent: .reservedBlocksChanged(anotherTrain), train: train), .reservedBlocksChanged(train))
        XCTAssertEqual(train.adjustSpeedCount, 1)

        train.onUpdateReservedBlocks = { false }
        XCTAssertEqual(try tsm.handle(trainEvent: .reservedBlocksChanged(anotherTrain), train: train), nil)
        XCTAssertEqual(train.adjustSpeedCount, 1)
    }

    func testChangeMode() throws {
        train.state = .running
        train.mode = .managed
        train.onUpdateReservedBlocks = { true }
        XCTAssertEqual(try tsm.handle(trainEvent: .modeChanged(train), train: train), .reservedBlocksChanged(train))

        train.onUpdateReservedBlocks = { false }
        XCTAssertEqual(try tsm.handle(trainEvent: .modeChanged(train), train: train), nil)

        train.mode = .stopManaged
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .modeChanged(train), train: train), nil)

        train.mode = .stopManaged
        train.stopFeedbackActivated = true
        XCTAssertEqual(try tsm.handle(trainEvent: .modeChanged(train), train: train), .stateChanged(train))
    }

    /// Ensure that even if a train is already stopped, changing the mode to ``Train.Schedule.stopManaged`` is still going to remove any reserved blocks.
    func testStopModeWhileStoppedState() throws {
        train.state = .stopped
        train.mode = .stopManaged
        train.hasReservedBlocks = true
        XCTAssertEqual(try tsm.handle(trainEvent: .modeChanged(train), train: train), .reservedBlocksChanged(train))
    }

    func testStateChange() throws {
        train.state = .running
        train.mode = .managed
        train.hasReservedBlocks = false
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .stateChanged(train), train: train), nil)
        XCTAssertEqual(train.state, .running)

        train.state = .stopped
        train.hasReservedBlocks = false
        train.onReservedBlocksLengthEnough = { _ in false }
        XCTAssertEqual(try tsm.handle(trainEvent: .stateChanged(train), train: train), nil)
        XCTAssertEqual(train.state, .stopped)

        train.state = .stopped
        train.hasReservedBlocks = false
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .stateChanged(train), train: train), .stateChanged(train))
        XCTAssertEqual(train.state, .running)

        train.state = .stopped
        train.hasReservedBlocks = true
        train.mode = .unmanaged
        XCTAssertEqual(try tsm.handle(trainEvent: .stateChanged(train), train: train), .reservedBlocksChanged(train))
        XCTAssertEqual(train.state, .stopped)
    }

    func testReservedBlockSettledChanged() throws {
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .reservedBlocksSettledLengthChanged(train), train: train), nil)
    }
    
    func testChangeDirectionWhenStartingRoute() throws {
        train.shouldChangeDirection = true
        train.mode = .managed
        train.state = .stopped
        train.onUpdateReservedBlocks = { true }
        XCTAssertEqual(try tsm.handle(trainEvent: .modeChanged(train), train: train), .reservedBlocksChanged(train))
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .reservedBlocksChanged(train), train: train), .stateChanged(train))
        XCTAssertEqual(train.changeDirectionCount, 1)
        XCTAssertFalse(train.shouldChangeDirection)
    }
    
    func testChangeDirectionAfterStopInRoute() throws {
        train.shouldChangeDirection = true
        train.mode = .managed
        train.state = .stopped
        train.onUpdateReservedBlocks = { true }
        XCTAssertEqual(try tsm.handle(trainEvent: .restartTimerFired(train), train: train), .reservedBlocksChanged(train))
        train.onReservedBlocksLengthEnough = { _ in true }
        XCTAssertEqual(try tsm.handle(trainEvent: .reservedBlocksChanged(train), train: train), .stateChanged(train))
        XCTAssertEqual(train.changeDirectionCount, 1)
        XCTAssertFalse(train.shouldChangeDirection)
    }
}

extension StateMachine.TrainEvent: Equatable {
    public static func == (lhs: StateMachine.TrainEvent, rhs: StateMachine.TrainEvent) -> Bool {
        switch (lhs, rhs) {
        case let (.position(t1), .position(t2)): return t1.id == t2.id
        case let (.speed(t1), .speed(t2)): return t1.id == t2.id
        case let (.modeChanged(t1), .modeChanged(t2)): return t1.id == t2.id
        case let (.stateChanged(t1), .stateChanged(t2)): return t1.id == t2.id
        case let (.restartTimerFired(t1), .restartTimerFired(t2)): return t1.id == t2.id
        case let (.reservedBlocksChanged(t1), .reservedBlocksChanged(t2)): return t1.id == t2.id
        case let (.reservedBlocksSettledLengthChanged(t1), .reservedBlocksSettledLengthChanged(t2)): return t1.id == t2.id
        default:
            return false
        }
    }
}
