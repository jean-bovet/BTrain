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

class TrainSpeedManagerTests: BTTestCase {
    
    override var speedChangeRequestCeiling: Int? {
        10
    }

    func testLinearAcceleration() {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationProfile = .linear
        let ic = TrainSpeedManager(train: t, interface: MockCommandInterface())
        
        assertChangeSpeed(train: t, from: 0, to: 20, [2, 4, 6, 8, 10, 12, 14, 15, 18, 19, 20], ic)
        assertChangeSpeed(train: t, from: 20, to: 13, [18, 16, 14, 13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [11, 9, 7, 5, 3, 1, 0], ic)
        
        // Simulate a change in the actual speed by the Digital Controller.
        // This means the TrainInertiaController needs to take that into account.
        t.speed.actualSteps = SpeedStep(value: 10)
        assertChangeSpeed(train: t, from: 10, to: 20, [12, 14, 16, 18, 20], ic)
    }

    func testBezierAcceleration() {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationProfile = .bezier
        let ic = TrainSpeedManager(train: t, interface: MockCommandInterface())
        
        assertChangeSpeed(train: t, from: 0, to: 40, [0, 1, 2, 4, 6, 8, 11, 14, 17, 19, 22, 25, 28, 31, 33, 35, 37, 38, 39, 40], ic)
        assertChangeSpeed(train: t, from: 40, to: 13, [39, 38, 36, 34, 32, 29, 26, 23, 20, 18, 16, 14, 13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [12, 10, 7, 5, 2, 0], ic)
        
        // Simulate a change in the actual speed by the Digital Controller.
        // This means the TrainInertiaController needs to take that into account.
        t.speed.actualSteps = SpeedStep(value: 10)
        assertChangeSpeed(train: t, from: 10, to: 20, [11, 13, 16, 18, 20], ic)
    }

    func testWithNoInertia() {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationProfile = .none
        let ic = TrainSpeedManager(train: t, interface: MockCommandInterface())

        assertChangeSpeed(train: t, from: 0, to: 20, [20], ic)
        assertChangeSpeed(train: t, from: 20, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [0], ic)
    }
    
    func testSpeedChangeWhenActualAndRequestSpeedsAreIdentical() {
        let t = Train()
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)

        t.speed.requestedSteps = SpeedStep(value: 100)
        t.speed.actualSteps = t.speed.requestedSteps

        let expectation = expectation(description: "Completed")
        ic.changeSpeed { completed in
            if completed {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeedChangeDuringProcessingOfCommandWhenActualAndRequestSpeedsAreIdentical() {
        let t = Train()
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)

        t.speed.requestedSteps = SpeedStep(value: 100)

        let e1 = expectation(description: "e1")
        ic.changeSpeed { completed in
            if !completed {
                e1.fulfill()
            }
        }
        
        wait(for: {
            t.speed.actualSteps.value >= 50
        }, timeout: 5.0)

        t.speed.requestedSteps = SpeedStep(value: 20)
        t.speed.actualSteps = t.speed.requestedSteps

        mi.pause()
        waitForPendingCommand(mi)

        let e2 = expectation(description: "e2")
        ic.changeSpeed { completed in
            if !completed {
                e2.fulfill()
            }
        }

        let e3 = expectation(description: "e3")
        ic.changeSpeed { completed in
            if completed {
                e3.fulfill()
            }
        }

        mi.resume()

        wait(for: [e1, e2, e3], timeout: 2.0, enforceOrder: true)
    }

    func testSpeedChangeDuringProcessingOfCommand() {
        let t = Train()
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)

        t.speed.requestedSteps = SpeedStep(value: 100)

        let e1 = expectation(description: "e1")
        ic.changeSpeed { completed in
            if !completed {
                e1.fulfill()
            }
        }

        wait(for: {
            t.speed.actualSteps.value >= 50
        }, timeout: 5.0)

        t.speed.requestedSteps = SpeedStep(value: 20)

        mi.pause()
        waitForPendingCommand(mi)

        let e2 = expectation(description: "e2")
        ic.changeSpeed { completed in
            if !completed {
                e2.fulfill()
            }
        }

        t.speed.requestedSteps = SpeedStep(value: 40)

        let e3 = expectation(description: "e3")
        ic.changeSpeed { completed in
            if completed {
                e3.fulfill()
            }
        }

        mi.resume()

        wait(for: [e1, e2, e3], timeout: 2.0, enforceOrder: true)
    }

    func testSpeedChangeFromDigitalController() {
        let t = Train()
        let mi = MockCommandInterface()
        _ = TrainSpeedManager(train: t, interface: mi)
        
        t.speed.requestedSteps = SpeedStep(value: 0)
        t.speed.actualSteps = t.speed.requestedSteps

        mi.callbacks.speedChanges.all[0](t.address, t.decoder, SpeedValue(value: 100), false)
        XCTAssertEqual(t.speed.requestedKph, 158)
        
        mi.callbacks.speedChanges.all[0](t.address, t.decoder, SpeedValue(value: 100), true)
        XCTAssertEqual(t.speed.requestedKph, 158)
        XCTAssertEqual(t.speed.actualKph, 158)
    }

    func testActualSpeedChangeHappensAfterDigitalControllerResponse() {
        let t = Train()
        t.speed.accelerationProfile = .none
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)

        t.speed.requestedSteps = SpeedStep(value: 100)

        let expectation = expectation(description: "Completed")
        ic.changeSpeed { _ in
            expectation.fulfill()
        }

        mi.pause()
        waitForPendingCommand(mi)

        // The actual speed shouldn't change yet, because the completion
        // block for the command request hasn't been invoked yet
        XCTAssertEqual(t.speed.actualSteps, .zero)

        mi.resume()

        // Now the actual speed should be set
        XCTAssertEqual(t.speed.requestedSteps, SpeedStep(value: 100))

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(t.speed.requestedSteps, SpeedStep(value: 100))
    }
    
    /// Ensure an in-progress speed change that gets cancelled is properly handled.
    /// We need to ensure that the completed parameter reflects the cancellation.
    func testSpeedChangeCancelPreviousSpeedChange() throws {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationStepDelay = 1
        t.speed.accelerationProfile = .linear
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)

        // Send a request to change the speed
        t.speed.requestedSteps = SpeedStep(value: 50)
        
        let cancelledSpeed50 = expectation(description: "Cancelled 50")
        ic.changeSpeed { completed in
            if !completed {
                cancelledSpeed50.fulfill()
            }
        }
                
        XCTAssertEqual(ic.commandQueue[0].requestedSteps.value, 50)
        
        // Wait until we have some speed set for the train (20 or above)
        wait(for: {
            t.speed.actualSteps.value >= 20
        }, timeout: 5.0)

        mi.pause()
        waitForPendingCommand(mi)
                        
        t.speed.requestedSteps = SpeedStep(value: 10)
        let cancelledSpeed10 = expectation(description: "Cancelled 10")
        ic.changeSpeed { completed in
            if !completed {
                cancelledSpeed10.fulfill()
            }
        }

        XCTAssertEqual(ic.commandQueue[0].requestedSteps.value, 50)
        
        t.speed.requestedSteps = SpeedStep(value: 0)
        let completedSpeed0 = expectation(description: "Completed 0")
        ic.changeSpeed { completed in
            if completed {
                completedSpeed0.fulfill()
            }
        }

        XCTAssertEqual(ic.commandQueue[0].requestedSteps.value, 50)

        mi.resume()
        
        XCTAssertEqual(ic.commandQueue[0].requestedSteps.value, 0)

        wait(for: [cancelledSpeed50, cancelledSpeed10, completedSpeed0], timeout: 5.0, enforceOrder: true)
        
        XCTAssertEqual(0, t.speed.actualSteps.value)
    }
    
    /// Ensure that the timer used during the settling of the stop of a locomotive is correctly
    /// cancelled when a new speed change is requested. We want to avoid that timer from
    /// firing with a "completed" status while is has been cancelled.
    func testSpeedChangeStopSettleDelay() throws {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationStepDelay = 1
        t.speed.stopSettleDelay = 2.0
        t.speed.accelerationProfile = .linear
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)

        // Let's test a braking situation where the speed goes down to 0
        t.speed.requestedSteps = SpeedStep(value: 50)
        t.speed.actualSteps = SpeedStep(value: 50)

        // Send a request to change the speed
        t.speed.requestedSteps = SpeedStep(value: 0)
        t.state = .running
        
        let cancelledChange = expectation(description: "Cancelled")
        ic.changeSpeed { completed in
            XCTAssertFalse(completed)
            if !completed {
                cancelledChange.fulfill()
            }
        }
        
        wait(for: {
            t.speed.actualSteps.value <= 20
        }, timeout: 5.0)

        XCTAssertEqual(t.state, .running)
        
        t.speed.requestedSteps = SpeedStep(value: 10)
        let completedChangeTo10 = expectation(description: "Completed")
        ic.changeSpeed { completed in
            if completed {
                completedChangeTo10.fulfill()
            }
        }

        // Ensure the cancellation of the previous speed change is properly handled
        wait(for: [cancelledChange], timeout: 5.0)

        // Ensure that the state of the train hasn't changed
        XCTAssertEqual(t.state, .running)

        wait(for: [completedChangeTo10], timeout: 5.0)
        XCTAssertEqual(t.speed.actualSteps.value, 10)
    }
        
    /// Ensure that scheduling a speed change while the stop settle timer is running works
    func testSpeedChangeStopSettleDelayWhileSchedulingNewSpeedChange() throws {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationStepDelay = 1
        t.speed.stopSettleDelay = 2.0
        t.speed.accelerationProfile = .linear
        let mi = MockCommandInterface()
        let settledDelayTimer = MockStopSettledDelayTimer()
        let ic = TrainSpeedManager(train: t, interface: mi)
        ic.stopSettlingDelayTimer = settledDelayTimer

        // Start with a speed of 50
        t.speed.requestedSteps = SpeedStep(value: 50)
        t.speed.actualSteps = SpeedStep(value: 50)

        // Send a request to change the speed to 0
        t.speed.requestedSteps = SpeedStep(value: 0)
        t.state = .running
        
        let changeSpeedTo0 = expectation(description: "speed0")
        ic.changeSpeed { completed in
            // Note: the command as completed even though the settled delay timer hasn't finished for it.
            if completed {
                changeSpeedTo0.fulfill()
            }
        }
                
        // Pause the settled delay timer
        settledDelayTimer.pause()
        
        wait(for: {
            t.speed.actualSteps.value == 0
        }, timeout: 5.0)

        XCTAssertEqual(t.state, .running)
        
        // Schedule a speed change request (while the settled delay timer is still
        // running - in our case here, we simulate that by having it paused).
        t.speed.requestedSteps = SpeedStep(value: 10)
        let changeSpeedTo10 = expectation(description: "speed10")
        ic.changeSpeed { completed in
            if completed {
                changeSpeedTo10.fulfill()
            }
        }

        settledDelayTimer.resume()

        wait(for: [changeSpeedTo0, changeSpeedTo10], timeout: 5.0, enforceOrder: true)
    }

    /// Ensure that a previous speed change callback that is being cancelled does not change
    /// the train state. For example, a train stopping can be restarted in the middle of being stopped;
    /// when that happen, the new state of .running should not be overridden by the previous callback.
    func testSpeedChangeCancelPreviousCompletionBlock() throws {
        let layout = LayoutYard().newLayout().removeTrainGeometry()
        let p = Package(layout: layout)
        
        let t = layout.trains[0]
        let block = layout.blocks[0]
        
        try p.prepare(trainID: t.id.uuid, fromBlockId: block.id.uuid)
        try p.start(routeID: t.routeId.uuid, trainID: t.id.uuid)
        
        // Ask the layout to stop the train
        p.layoutController.stop(train: t)

        p.toggle("A.1")

        wait(for: {
            t.state == .braking
        }, timeout: 1.0)

        p.toggle("A.2", drainAll: false)

        wait(for: {
            t.state == .stopping
        }, timeout: 1.0)
        
        // Ask to restart the train before it has a change to fully stop
        try p.start(routeID: t.routeId.uuid, trainID: t.id.uuid, expectedState: .running)
                
        p.layoutController.stop(train: t)
        p.layoutController.waitUntilSettled()
    }
    
    func testMultipleIdenticalSpeedRequests() {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationProfile = .bezier
        
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)
                
        t.speed.requestedKph = 80
        mi.pause()
        let e1 = expectation(description: "e1")
        ic.changeSpeed { completed in
            XCTAssertFalse(completed)
            e1.fulfill()
        }

        // Wait for the command interface to receive the speed command
        waitForPendingCommand(mi)

        t.speed.requestedKph = 40

        let e2 = expectation(description: "e2")
        ic.changeSpeed { completed in
            XCTAssertFalse(completed)
            e2.fulfill()
        }

        let e3 = expectation(description: "e3")
        ic.changeSpeed { completed in
            XCTAssertTrue(completed)
            e3.fulfill()
        }
        
        mi.resume()

        wait(for: [e1, e2, e3], timeout: 1.0, enforceOrder: true)
    }

    func testIdenticalRequestToCancelledProcessingCommand() {
        let t = Train(id: .init(uuid: "1"), name: "CFF", address: 0)
        t.speed.accelerationProfile = .bezier
        
        let mi = MockCommandInterface()
        let ic = TrainSpeedManager(train: t, interface: mi)
        
        let previousRequestUUID = TrainSpeedManager.globalRequestUUID
        
        t.speed.requestedKph = 80
        mi.pause()
        let e1 = expectation(description: "Completion e1")
        ic.changeSpeed { completed in
            XCTAssertFalse(completed)
            e1.fulfill()
        }

        // Wait for the command interface to receive the speed command
        waitForPendingCommand(mi)

        t.speed.requestedKph = 0
        let e2 = expectation(description: "Completion e2")
        ic.changeSpeed { completed in
            // Note: completed is true because the actual speed of the train is 0 (the first changeSpeed of 80 has been cancelled)
            XCTAssertTrue(completed)
            e2.fulfill()
        }
        
        t.speed.requestedKph = 80
        let e3 = expectation(description: "Completion e3")
        ic.changeSpeed { completed in
            XCTAssertTrue(completed)
            e3.fulfill()
        }

        XCTAssertEqual(TrainSpeedManager.globalRequestUUID - previousRequestUUID, 3)
        
        mi.resume()

        wait(for: [e1, e2, e3], timeout: 1.0, enforceOrder: true)
    }

    private func assertChangeSpeed(train: Train, from fromSteps: UInt16, to steps: UInt16, _ expectedSteps: [UInt16], _ ic: TrainSpeedManager) {
        XCTAssertEqual(train.speed.actualSteps.value, fromSteps, "Actual step value does not match")

        let cmd = ic.interface as! MockCommandInterface

        cmd.speedValues.removeAll()

        train.speed.requestedSteps = SpeedStep(value: steps)
        
        let expectation = expectation(description: "Completed")
        ic.changeSpeed { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
        
        XCTAssertEqual(train.speed.requestedSteps.value, steps)
        XCTAssertEqual(train.speed.actualSteps.value, steps)

        XCTAssertEqual(train.speed.actualSteps.value, steps)

        XCTAssertEqual(cmd.speedValues, expectedSteps)
        cmd.speedValues.removeAll()
    }
    
    private func waitForPendingCommand(_ mi: MockCommandInterface) {
        wait(for: {
            mi.pendingCommands.count > 0
        }, timeout: 1.0)
    }
}

/// A settled timer implementation that can be paused and resumed, to simulate the timer taking some time
final class MockStopSettledDelayTimer: StopSettledDelayTimer {
    
    typealias SettledBlock = (Bool) -> Void
    
    var paused = false
    var blocks = [(Bool, SettledBlock)]()
    
    func schedule(train: Train, completed: Bool, completion: @escaping SettledBlock) {
        if paused {
            blocks.append((completed, completion))
        } else {
            completion(completed)
        }
    }
    
    func cancel() {
        blocks.removeAll()
    }
    
    func pause() {
        paused = true
    }
    
    func resume() {
        paused = false
        blocks.forEach { $1($0) }
    }
}

