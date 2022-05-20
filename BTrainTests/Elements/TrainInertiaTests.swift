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

    func testTrainSpecificValues() {
        let t = Train()

        var ic = TrainControllerAcceleration(train: t, interface: MockCommandInterface())
        XCTAssertEqual(TrainControllerAcceleration.DefaultStepSize, ic.stepIncrement)
        XCTAssertEqual(Double(TrainControllerAcceleration.DefaultStepDelay)/1000, ic.stepDelay)

        t.speed.accelerationStepSize = 3
        t.speed.accelerationStepDelay = 250

        // The values don't change after initialization of the TrainControllerAcceleration
        XCTAssertEqual(TrainControllerAcceleration.DefaultStepSize, ic.stepIncrement)
        XCTAssertEqual(Double(TrainControllerAcceleration.DefaultStepDelay)/1000, ic.stepDelay)

        ic = TrainControllerAcceleration(train: t, interface: MockCommandInterface())

        XCTAssertEqual(3, ic.stepIncrement)
        XCTAssertEqual(0.250, ic.stepDelay)
    }
    
    func testLinearAcceleration() {
        let t = Train()
        t.speed.accelerationProfile = .linear
        let ic = TrainControllerAcceleration(train: t, interface: MockCommandInterface())
        
        assertChangeSpeed(train: t, from: 0, to: 20, [2, 4, 6, 8, 10, 12, 14, 15, 18, 19, 20], ic)
        assertChangeSpeed(train: t, from: 20, to: 13, [18, 16, 14, 13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [11, 9, 7, 5, 3, 1, 0], ic)
        
        // Simulate a change in the actual speed by the Digital Controller.
        // This means the TrainInertiaController needs to take that into account.
        t.speed.actualSteps = SpeedStep(value: 10)
        assertChangeSpeed(train: t, from: 0, to: 20, [12, 14, 16, 18, 20], ic)
    }

    func testBezierAcceleration() {
        let t = Train()
        t.speed.accelerationProfile = .bezier
        let ic = TrainControllerAcceleration(train: t, interface: MockCommandInterface())
        
        assertChangeSpeed(train: t, from: 0, to: 40, [0, 1, 2, 4, 6, 8, 11, 14, 17, 19, 22, 25, 28, 31, 33, 35, 37, 38, 39, 40], ic)
        assertChangeSpeed(train: t, from: 40, to: 13, [39, 38, 36, 34, 32, 29, 26, 23, 20, 18, 16, 14, 13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [12, 10, 7, 5, 2, 0], ic)
        
        // Simulate a change in the actual speed by the Digital Controller.
        // This means the TrainInertiaController needs to take that into account.
        t.speed.actualSteps = SpeedStep(value: 10)
        assertChangeSpeed(train: t, from: 0, to: 20, [11, 13, 16, 18, 20], ic)
    }

    func testWithNoInertia() {
        let t = Train()
        t.speed.accelerationProfile = .none
        let ic = TrainControllerAcceleration(train: t, interface: MockCommandInterface())

        assertChangeSpeed(train: t, from: 0, to: 20, [20], ic)
        assertChangeSpeed(train: t, from: 20, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [0], ic)
    }
    
    func testActualSpeedChangeHappensAfterDigitalControllerResponse() {
        let t = Train()
        t.speed.accelerationProfile = .none
        let mi = ManualCommandInterface()
        let ic = TrainControllerAcceleration(train: t, interface: mi)

        t.speed.requestedSteps = SpeedStep(value: 100)
        
        let expectation = expectation(description: "Completed")
        ic.changeSpeed(of: t, acceleration: nil) { _ in
            expectation.fulfill()
        }
        
        wait(for: {
            mi.onCompletion != nil
        }, timeout: 1.0)
        
        // The actual speed shouldn't change yet, because the completion
        // block for the command request hasn't been invoked yet
        XCTAssertEqual(t.speed.actualSteps, .zero)
        
        mi.onCompletion!()
        // Now the actual speed should be set
        XCTAssertEqual(t.speed.requestedSteps, SpeedStep(value: 100))

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(t.speed.requestedSteps, SpeedStep(value: 100))
    }
    
    /// Ensure an in-progress speed change that gets cancelled is properly handled.
    /// We need to ensure that the completed parameter reflects the cancellation.
    func testSpeedChangeCancelPreviousSpeedChange() throws {
        let t = Train()
        t.speed.accelerationStepDelay = 1
        t.speed.accelerationProfile = .linear
        let mi = MockCommandInterface()
        let ic = TrainControllerAcceleration(train: t, interface: mi)

        // Send a request to change the speed
        t.speed.requestedSteps = SpeedStep(value: 50)
        
        let cancelledChange = expectation(description: "Cancelled")
        ic.changeSpeed(of: t, acceleration: nil) { completed in
            if !completed {
                cancelledChange.fulfill()
            }
        }
        
        wait(for: {
            t.speed.actualSteps.value >= 20
        }, timeout: 5.0)

        t.speed.requestedSteps = SpeedStep(value: 10)
        let completedChange = expectation(description: "Completed")
        ic.changeSpeed(of: t, acceleration: nil) { completed in
            if completed {
                completedChange.fulfill()
            }
        }

        wait(for: [cancelledChange, completedChange], timeout: 5.0, enforceOrder: true)
        
        XCTAssertEqual(10, t.speed.actualSteps.value)
    }
    
    /// Ensure that the timer used during the settling of the stop of a locomotive is correctly
    /// cancelled when a new speed change is requested. We want to avoid that timer from
    /// firing with a "completed" status while is has been cancelled.
    func testSpeedChangeStopSettleDelay() throws {
        let t = Train()
        t.speed.accelerationStepDelay = 1
        t.speed.stopSettleDelay = 2.0
        t.speed.accelerationProfile = .linear
        let mi = MockCommandInterface()
        let ic = TrainControllerAcceleration(train: t, interface: mi)

        // Let's test a braking situation where the speed goes down to 0
        t.speed.requestedSteps = SpeedStep(value: 50)
        t.speed.actualSteps = SpeedStep(value: 50)

        // Send a request to change the speed
        t.speed.requestedSteps = SpeedStep(value: 0)
        t.state = .running
        
        let cancelledChange = expectation(description: "Cancelled")
        ic.changeSpeed(of: t, acceleration: nil) { completed in
            XCTAssertFalse(completed)
            if !completed {
                cancelledChange.fulfill()
            }
        }
        
        wait(for: {
            t.speed.actualSteps.value == 0
        }, timeout: 5.0)

        XCTAssertEqual(0, t.speed.actualSteps.value)
        XCTAssertEqual(.running, t.state)
        
        t.speed.requestedSteps = SpeedStep(value: 10)
        let completedChangeTo10 = expectation(description: "Completed")
        ic.changeSpeed(of: t, acceleration: nil) { completed in
            if completed {
                completedChangeTo10.fulfill()
            }
        }

        // Ensure the cancellation of the previous speed change is properly handled
        wait(for: [cancelledChange], timeout: 5.0)

        // Ensure that the state of the train hasn't changed
        XCTAssertEqual(.running, t.state)
        
        wait(for: [completedChangeTo10], timeout: 5.0)
        XCTAssertEqual(10, t.speed.actualSteps.value)
    }
    
    /// Ensure that a previous speed change callback that is being cancelled does not change
    /// the train state. For example, a train stopping can be restarted in the middle of being stopped;
    /// when that happen, the new state of .running should not be overriden by the previous callback.
    func testSpeedChangeCancelPreviousCompletionBlock() throws {
        let layout = LayoutYard().newLayout()
        let mexec = ManualCommandExecutor()
        layout.executing = mexec
        
        let t = layout.trains[0]
        try layout.setTrainToBlock(t.id, layout.blocks[0].id, direction: .next)
        
        t.state = .running
        
        // Ask the layout to stop the train
        let stopCompletion = expectation(description: "Completed")
        try layout.stopTrain(t.id, completely: true) {
            stopCompletion.fulfill()
        }
        
        XCTAssertEqual(.stopping, t.state)
        
        // Simulate a cancellation of the speed change request which should not change the state of the train
        mexec.onSpeedCompletion?(false)
        wait(for: [stopCompletion], timeout: 1.0)
        XCTAssertEqual(.stopping, t.state)
        
        // Reset the train state and try again, this time by completing the speed change request fully.
        t.state = .running

        let stopCompletion2 = expectation(description: "Completed")
        try layout.stopTrain(t.id, completely: true) {
            stopCompletion2.fulfill()
        }

        // Simulate a completion of the speed change request which should, this time, change the train state
        mexec.onSpeedCompletion?(true)
        wait(for: [stopCompletion2], timeout: 1.0)
        XCTAssertEqual(.stopped, t.state)
    }
    
    private func assertChangeSpeed(train: Train, from fromSteps: UInt16, to steps: UInt16, _ expectedSteps: [UInt16], _ ic: TrainControllerAcceleration) {
        XCTAssertEqual(ic.actual.value, fromSteps)

        let cmd = ic.interface as! MockCommandInterface

        cmd.speedValues.removeAll()

        train.speed.requestedSteps = SpeedStep(value: steps)
        
        let expectation = expectation(description: "Completed")
        ic.changeSpeed(of: train, acceleration: nil) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertEqual(ic.desired.value, steps)
        XCTAssertEqual(ic.actual.value, steps)

        XCTAssertEqual(train.speed.actualSteps.value, steps)

        XCTAssertEqual(cmd.speedValues, expectedSteps)
        cmd.speedValues.removeAll()
    }
    
}

// TODO: refactor with the other similar mock class
class ManualCommandExecutor: LayoutCommandExecuting {
    
    var forwardExecutor: LayoutCommandExecuting?
    
    var pauseTurnout = false
    var pendingTurnouts = [Turnout]()
    
    var trainsScheduledToRestart = [Train]()
    
    var onSpeedCompletion: CompletionCancelBlock?

    func scheduleRestartTimer(train: Train) {
        trainsScheduledToRestart.append(train)
    }

    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        if pauseTurnout {
            pendingTurnouts.append(turnout)
        } else {
            for turnout in pendingTurnouts + [turnout] {
                if let forwardExecutor = forwardExecutor {
                    forwardExecutor.sendTurnoutState(turnout: turnout, completion: completion)
                } else {
                    completion()
                }
            }
            pendingTurnouts.removeAll()
        }
    }
    
    func sendTrainDirection(train: Train, forward: Bool, completion: @escaping CompletionBlock) {
        if let forwardExecutor = forwardExecutor {
            forwardExecutor.sendTrainDirection(train: train, forward: forward, completion: completion)
        } else {
            completion()
        }
    }
    
    func sendTrainSpeed(train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock) {
        onSpeedCompletion = completion
//        if let forwardExecutor = forwardExecutor {
//            forwardExecutor.sendTrainSpeed(train: train, acceleration: acceleration, completion: completion)
//        } else {
//            completion(true)
//        }
    }
        
}

extension TrainControllerAcceleration {
    
    var stepIncrement: Int {
        return speedChangeTimer.stepIncrement
    }
    var stepDelay: TimeInterval {
        return speedChangeTimer.stepDelay
    }
    var actual: SpeedStep {
        return speedChangeTimer.actual
    }
    var desired: SpeedStep {
        return speedChangeTimer.desired
    }
}

class MockCommandInterface: CommandInterface {
    
    var speedValues = [UInt16]()
    
    var metrics: [Metric] {
        []
    }
    
    func connect(server: String, port: UInt16, onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        
    }
    
    func disconnect(_ completion: @escaping CompletionBlock) {
        
    }
    
    func execute(command: Command, onCompletion: @escaping () -> Void) {
        if case .speed(address: _, decoderType: _, value: let value, priority: _, descriptor: _) = command {
            speedValues.append(value.value)
        }
        DispatchQueue.main.async {
            onCompletion()
        }
    }
    
    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        return .init(value: steps.value)
    }
    
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        return .init(value: value.value)
    }
    
    func register(forFeedbackChange: @escaping FeedbackChangeCallback) -> UUID {
        return UUID()
    }
    
    func register(forSpeedChange: @escaping SpeedChangeCallback) {
        
    }
    
    func register(forDirectionChange: @escaping DirectionChangeCallback) {
        
    }
    
    func register(forTurnoutChange: @escaping TurnoutChangeCallback) {
        
    }
    
    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) {
        
    }
    
    func unregister(uuid: UUID) {
        
    }
            
}

class ManualCommandInterface: MockCommandInterface {
    
    var onCompletion: CompletionBlock?
    
    override func execute(command: Command, onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
    }
    
}
