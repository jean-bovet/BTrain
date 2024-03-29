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

class LayoutStateMachineTests: XCTestCase {
    var train: MockTrainController!
    let sm = LayoutStateMachine()

    override func setUp() {
        super.setUp()
        train = MockTrainController()
    }

    func testTrainStart() {
        XCTAssertEqual(train.state, .stopped)
        train.scheduling = .managed

        train.onReservedBlocksLengthEnough = { _ in
            false
        }
        train.onUpdateReservedBlocks = {
            true
        }
        handle(trainEvent: .scheduling(train), train: train, handledEvents: [.scheduling(train), .reservedBlocksChanged(train)])

        XCTAssertEqual(train.state, .stopped)
        XCTAssertEqual(train.adjustSpeedCount, 1)
        XCTAssertEqual(train.speed, 0)

        train.onReservedBlocksLengthEnough = { _ in
            true
        }
        train.onUpdateReservedBlocks = {
            true
        }
        handle(trainEvent: .scheduling(train), train: train, handledEvents: [.scheduling(train), .reservedBlocksChanged(train), .stateChanged(train)])

        XCTAssertEqual(train.state, .running)
        XCTAssertEqual(train.adjustSpeedCount, 2)
        XCTAssertEqual(train.speed, LayoutFactory.DefaultMaximumSpeed)
    }

    func testTrainStart2() {
        let t1 = MockTrainController()
        let t2 = MockTrainController()

        XCTAssertEqual(t1.state, .stopped)
        XCTAssertEqual(t2.state, .stopped)

        t1.scheduling = .managed

        t1.onReservedBlocksLengthEnough = { _ in
            true
        }

        t1.onUpdateReservedBlocks = {
            true
        }

        handle(trainEvent: .scheduling(t1), trains: [t1, t2], handledEvents: [.scheduling(t1), .reservedBlocksChanged(t1), .stateChanged(t1)])

        XCTAssertEqual(t1.state, .running)
        XCTAssertEqual(t1.updateReservedBlocksInvocationCount, 1)

        XCTAssertEqual(t2.state, .stopped)
        XCTAssertEqual(t2.updateReservedBlocksInvocationCount, 1)
    }

    func testTrainMove() {
        train.scheduling = .managed
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        let f1 = Feedback("f1")

        train.onReservedBlocksLengthEnough = { _ in true }
        train.onUpdatePosition = { f in f == f1 }
        train.onUpdateOccupiedAndReservedBlocks = { true }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 1)

        // f2 does not trigger a change in position for the train, which translates into no handled events for the train.
        let f2 = Feedback("f2")
        handle(layoutEvent: .feedback(f2), train: train, handledEvents: [])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 2)
    }

    func testTrainMoveAndBrakeBecauseSettledDistance() {
        train.scheduling = .managed
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in f == f1 }
        train.onReservedBlocksLengthEnough = { speed in
            if speed == LayoutFactory.DefaultMaximumSpeed {
                return false
            } else {
                return true
            }
        }
        train.onUpdateOccupiedAndReservedBlocks = {
            true
        }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .braking, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 1)
    }

    func testTrainMoveAndStopBecauseSettledDistance() {
        train.scheduling = .managed
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in f == f1 }
        train.onReservedBlocksLengthEnough = { _ in
            false
        }
        train.onUpdateOccupiedAndReservedBlocks = {
            true
        }
        // Note: 2 state changes, running>braking>stopping because the length of the reserved block does not allow the train to run at all.
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train), .stateChanged(train)])
        assert(train, .stopping, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 1)

        handle(layoutEvent: .speed(train, 0), train: train, handledEvents: [.stateChanged(train)])
        assert(train, .stopped, 0, reservedBlock: false, updatePositionCount: 1)
    }

    func testTrainMoveBrakeAndRunBecauseSettledDistance() {
        train.scheduling = .managed
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in f == f1 }
        train.onReservedBlocksLengthEnough = { speed in
            if speed == LayoutFactory.DefaultMaximumSpeed {
                return false
            } else {
                return true
            }
        }
        train.onUpdateOccupiedAndReservedBlocks = {
            true
        }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .braking, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 1)

        train.onReservedBlocksLengthEnough = { _ in
            true
        }

        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 2)
    }

    func testTrainStopManaged() {
        assertTrainStop {
            train.scheduling = .stopManaged
        }
    }

    func testTrainStopManagedAtEndOfRoute() {
        assertTrainStop {
            train.moveToEndOfRoute()
            train.scheduling = .stopManaged
        }
    }

    func testTrainFinishManaged() {
        assertTrainStop {
            train.moveToEndOfRoute()
            train.scheduling = .finishManaged
        }
    }

    func testTrainStopAtEndOfRoute() {
        assertTrainStop {
            train.moveToEndOfRoute()
        }
    }

    func testTrainStopAtStation() {
        assertTrainStop {
            train.atStation = true
        }
    }

    private func assertTrainStop(stopTrigger: CompletionBlock) {
        train.scheduling = .managed
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in
            self.train.currentRouteIndex += 1
            return f == f1
        }
        train.onReservedBlocksLengthEnough = { _ in
            true
        }
        train.onUpdateOccupiedAndReservedBlocks = {
            true
        }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 1)

        stopTrigger()
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 2)

        train.brakeFeedbackActivated = true
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .braking, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 3)

        train.brakeFeedbackActivated = false
        train.stopFeedbackActivated = true
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .stopping, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 4)

        handle(layoutEvent: .speed(train, 0), train: train, handledEvents: [.stateChanged(train)])
        assert(train, .stopped, 0, reservedBlock: false, updatePositionCount: 4)

        // Ensure stability by making sure the train does not restart if there is a layout event happening
        handle(layoutEvent: .speed(train, 0), train: train, handledEvents: [])
        assert(train, .stopped, 0, reservedBlock: false, updatePositionCount: 4)

        // And now test when the feedback is used for both the braking and stopping feedback
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        train.brakeFeedbackActivated = true
        train.stopFeedbackActivated = true
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train), .stateChanged(train)])
        assert(train, .stopping, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 5)
    }

    func testTrainStopAtStationAndRestart() {
        train.scheduling = .managed
        train.state = .running
        train.speed = LayoutFactory.DefaultMaximumSpeed

        let f1 = Feedback("f1")

        train.onUpdatePosition = { f in
            self.train.currentRouteIndex += 1
            return f == f1
        }
        train.onUpdateReservedBlocks = {
            true
        }
        train.onReservedBlocksLengthEnough = { _ in
            true
        }
        train.onUpdateOccupiedAndReservedBlocks = {
            true
        }
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 1)

        train.atStation = true
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 2)

        train.stopFeedbackActivated = true
        handle(layoutEvent: .feedback(f1), train: train, handledEvents: [.reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .stopping, LayoutFactory.DefaultBrakingSpeed, updatePositionCount: 3)

        handle(layoutEvent: .speed(train, 0), train: train, handledEvents: [.stateChanged(train)])
        assert(train, .stopped, 0, reservedBlock: false, updatePositionCount: 3)

        // Ensure the train stays stopped
        handle(layoutEvent: .speed(train, 0), train: train, handledEvents: [])
        assert(train, .stopped, 0, reservedBlock: false, updatePositionCount: 3)

        // Simulate the restart timer firing
        handle(trainEvent: .restartTimerFired(train), train: train, handledEvents: [.restartTimerFired(train), .reservedBlocksChanged(train), .stateChanged(train)])
        assert(train, .running, LayoutFactory.DefaultMaximumSpeed, updatePositionCount: 3)
    }
}

// MARK: - Extensions

extension LayoutStateMachineTests {
    func handle(layoutEvent: StateMachine.LayoutEvent? = nil, trainEvent: StateMachine.TrainEvent? = nil, train: TrainControlling, handledEvents: [StateMachine.TrainEvent]) {
        handle(layoutEvent: layoutEvent, trainEvent: trainEvent, trains: [train], handledEvents: handledEvents)
    }

    func handle(layoutEvent: StateMachine.LayoutEvent? = nil, trainEvent: StateMachine.TrainEvent? = nil, trains: [TrainControlling], handledEvents: [StateMachine.TrainEvent]) {
        var actualHandledEvents: [StateMachine.TrainEvent]? = [StateMachine.TrainEvent]()
        sm.handle(layoutEvent: layoutEvent, trainEvent: trainEvent, trains: trains, handledTrainEvents: &actualHandledEvents)
        XCTAssertEqual(actualHandledEvents, handledEvents)
    }

    func assert(_ train: MockTrainController, _ state: StateMachine.TrainState, _ speed: TrainSpeed.UnitKph, reservedBlock: Bool = true, updatePositionCount: Int) {
        XCTAssertEqual(train.state, state)
        XCTAssertEqual(train.speed, speed)
        XCTAssertEqual(train.hasReservedBlocks, reservedBlock)
        XCTAssertEqual(train.updatePositionInvocationCount, updatePositionCount)
    }
}
