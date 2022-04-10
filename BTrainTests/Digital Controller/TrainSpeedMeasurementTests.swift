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

class TrainSpeedMeasurementTests: XCTestCase {

    var mi: MarklinInterface!
    var simulator: MarklinCommandSimulator!

    override func setUp() {
        let connectedExpection = XCTestExpectation()
        mi = MarklinInterface()
        
        simulator = MarklinCommandSimulator(layout: Layout(), interface: mi)
        simulator.start()

        mi.connect(server: "localhost", port: 15731) {
            connectedExpection.fulfill()
        } onError: { error in
            XCTAssertNil(error)
        } onStop: {
            
        }

        wait(for: [connectedExpection], timeout: 0.5)
    }
    
    override func tearDown() {
        simulator.stop()
        
        let disconnectExpectation = XCTestExpectation()
        mi.disconnect() {
            disconnectExpectation.fulfill()
        }
        wait(for: [disconnectExpectation], timeout: 5.0)
    }

    func testCancelMeasure() throws {
        let layout = LayoutComplex().newLayout()
        
        let train = layout.trains[0]
        train.blockId = layout.blocks[0].id
        layout.blocks[0].train = .init(train.id, .next)

        let fa = layout.feedback(for: Identifier<Feedback>(uuid: "OL1.2"))!
        let fb = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.1"))!
        let fc = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.2"))!

        let step = 10

        let sm = TrainSpeedMeasurement(layout: layout, interface: mi, train: train,
                                       speedEntries: [UInt16(step)],
                                       feedbackA: fa.id, feedbackB: fb.id, feedbackC: fc.id,
                                       distanceAB: 95, distanceBC: 18,
                                       simulator: true)

        let trainStartedExpectation = expectation(description: "TrainStarted")

        sm.start { info in
            if info.step == .trainStarted {
                trainStartedExpectation.fulfill()
            } else {
                XCTFail("Unexpected info.step \(info.step)")
            }
        }
        
        wait(for: [trainStartedExpectation], timeout: 5.0)
        
        // Wait for the speed measurement class to be waiting for feedback A trigger
        wait(for: {
            sm.feedbackMonitor.pendingRequestCount == 1
        }, timeout: 1.0)
        
        // Cancel the speed measurement
        sm.cancel()
        
        // And check that it is not waiting for feedback A anymore, because cancel()
        // should have removed and cancelled that wait
        XCTAssertEqual(sm.feedbackMonitor.pendingRequestCount, 0)
    }
    
    func testMeasureOneStep() throws {
        let layout = LayoutComplex().newLayout()
        
        let train = layout.trains[0]
        train.blockId = layout.blocks[0].id
        layout.blocks[0].train = .init(train.id, .next)

        let fa = layout.feedback(for: Identifier<Feedback>(uuid: "OL1.2"))!
        let fb = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.1"))!
        let fc = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.2"))!

        let step = 10
        
        train.speed.speedTable[step] = .init(steps: SpeedStep(value: UInt16(step)), speed: nil)
        XCTAssertNil(train.speed.speedTable[step].speed)

        let sm = TrainSpeedMeasurement(layout: layout, interface: mi, train: train,
                                       speedEntries: [UInt16(step)],
                                       feedbackA: fa.id, feedbackB: fb.id, feedbackC: fc.id,
                                       distanceAB: 95, distanceBC: 18,
                                       simulator: true)

        var expectedInfoArray: [TrainSpeedMeasurement.CallbackStep] = [.trainStarted, .feedbackA, .feedbackB, .feedbackC, .trainStopped, .trainDirectionToggle, .done]
        
        let callbackExpectation = expectation(description: "Callback")
        callbackExpectation.expectedFulfillmentCount = expectedInfoArray.count

        let trainStartedExpectation = expectation(description: "TrainStarted")
        let feedbackAExpectation = expectation(description: "Feedback A")
        let feedbackBExpectation = expectation(description: "Feedback B")

        sm.start() { info in
            XCTAssertEqual(info.progress, 1)
            let expectedInfo = expectedInfoArray.removeFirst()
            XCTAssertEqual(expectedInfo, info.step)
            if info.step == .trainStarted {
                trainStartedExpectation.fulfill()
            }
            if info.step == .feedbackA {
                feedbackAExpectation.fulfill()
            }
            if info.step == .feedbackB {
                feedbackBExpectation.fulfill()
            }
            callbackExpectation.fulfill()
        }
        
        wait(for: [trainStartedExpectation], timeout: 5.0)

        simulator.triggerFeedback(feedback: fa)

        wait(for: [feedbackAExpectation], timeout: 5.0)

        simulator.triggerFeedback(feedback: fb)

        wait(for: [feedbackBExpectation], timeout: 5.0)

        wait(for: 0.2)

        simulator.triggerFeedback(feedback: fc)

        wait(for: [callbackExpectation], timeout: 5.0)

        XCTAssertEqual(expectedInfoArray.count, 0)
        XCTAssertEqual(train.speed.speedTable[step].steps.value, UInt16(step))
        XCTAssertNotNil(train.speed.speedTable[step].speed)
        XCTAssertEqual(sm.feedbackMonitor.pendingRequestCount, 0)
    }

    final class InfoStepAsserter {
        var actualInfoStepArray = [TrainSpeedMeasurement.CallbackStep]()
        
        func assert(step: TrainSpeedMeasurement.CallbackStep) {
            wait(for: {
                if actualInfoStepArray.isEmpty {
                    return false
                } else {
                    return actualInfoStepArray.removeFirst() == step
                }
            }, timeout: 2.0)
        }
        
        func wait(for block: () -> Bool, timeout: TimeInterval) {
            let current = RunLoop.current
            let startTime = Date()
            while !block() {
                current.run(until: Date(timeIntervalSinceNow: 0.250))
                if Date().timeIntervalSince(startTime) >= timeout {
                    XCTFail("Time out")
                    break
                }
            }
        }

    }
    
    func testMeasureTwoStep() throws {
        let layout = LayoutComplex().newLayout()
        
        let train = layout.trains[0]
        train.blockId = layout.blocks[0].id
        layout.blocks[0].train = .init(train.id, .next)

        let fa = layout.feedback(for: Identifier<Feedback>(uuid: "OL1.2"))!
        let fb = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.1"))!
        let fc = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.2"))!

        let step1 = 10
        let step2 = 20

        train.speed.speedTable[step1] = .init(steps: SpeedStep(value: UInt16(step1)), speed: nil)
        train.speed.speedTable[step2] = .init(steps: SpeedStep(value: UInt16(step2)), speed: nil)
        XCTAssertNil(train.speed.speedTable[step1].speed)
        XCTAssertNil(train.speed.speedTable[step2].speed)

        let sm = TrainSpeedMeasurement(layout: layout, interface: mi, train: train,
                                       speedEntries: [UInt16(step1), UInt16(step2)],
                                       feedbackA: fa.id, feedbackB: fb.id, feedbackC: fc.id,
                                       distanceAB: 95, distanceBC: 18, simulator: true)
                
        var expectedInfoArray: [TrainSpeedMeasurement.CallbackStep] = [.trainStarted, .feedbackA, .feedbackB, .feedbackC, .trainStopped, .trainDirectionToggle,
                                                                       .trainStarted, .feedbackC, .feedbackB, .feedbackA, .trainStopped, .trainDirectionToggle, .done]
        
        let callbackExpectation = expectation(description: "Callback")
        callbackExpectation.expectedFulfillmentCount = expectedInfoArray.count
        
        let infoStepAsserter = InfoStepAsserter()
        
        sm.start() { info in
            callbackExpectation.fulfill()

            let expectedInfo = expectedInfoArray.removeFirst()
            infoStepAsserter.actualInfoStepArray.append(info.step)
            XCTAssertEqual(expectedInfo, info.step)
        }
        
        infoStepAsserter.assert(step: .trainStarted)
                
        simulator.triggerFeedback(feedback: fa)

        infoStepAsserter.assert(step: .feedbackA)

        simulator.triggerFeedback(feedback: fb)

        infoStepAsserter.assert(step: .feedbackB)

        wait(for: 0.2)

        simulator.triggerFeedback(feedback: fc)

        infoStepAsserter.assert(step: .feedbackC)
        infoStepAsserter.assert(step: .trainStopped)
        infoStepAsserter.assert(step: .trainDirectionToggle)
        infoStepAsserter.assert(step: .trainStarted)

        simulator.triggerFeedback(feedback: fc)

        infoStepAsserter.assert(step: .feedbackC)

        simulator.triggerFeedback(feedback: fb)

        infoStepAsserter.assert(step: .feedbackB)

        wait(for: 0.2)

        simulator.triggerFeedback(feedback: fa)
        
        infoStepAsserter.assert(step: .feedbackA)
        infoStepAsserter.assert(step: .trainDirectionToggle)
        infoStepAsserter.assert(step: .done)

        XCTAssertEqual(expectedInfoArray.count, 0)

        wait(for: [callbackExpectation], timeout: 5.0)

        XCTAssertEqual(train.speed.speedTable[step1].steps.value, UInt16(step1))
        XCTAssertNotNil(train.speed.speedTable[step1].speed)
        
        XCTAssertEqual(train.speed.speedTable[step2].steps.value, UInt16(step2))
        XCTAssertNotNil(train.speed.speedTable[step2].speed)
        
        XCTAssertNotEqual(train.speed.speedTable[step1].steps.value, train.speed.speedTable[step2].steps.value)
        XCTAssertEqual(sm.feedbackMonitor.pendingRequestCount, 0)
    }
    
}
