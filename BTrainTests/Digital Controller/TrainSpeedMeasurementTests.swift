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

class TrainSpeedMeasurementTests: BTTestCase {

    func testCancelMeasure() throws {
        let layout = LayoutComplex().newLayout()
        let doc = LayoutDocument(layout: layout)
        
        connectToSimulator(doc: doc) { }
        defer {
            disconnectFromSimulator(doc: doc)
        }
        
        let train = layout.trains[0]
        train.blockId = layout.blocks[0].id
        layout.blocks[0].train = .init(train.id, .next)

        let fa = layout.feedback(for: Identifier<Feedback>(uuid: "OL1.2"))!
        let fb = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.1"))!
        let fc = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.2"))!

        let step = 10

        let sm = TrainSpeedMeasurement(layout: layout, executor: doc.layoutController, interface: doc.interface, train: train,
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
        layout.trains = [layout.trains[0]]
        
        let doc = LayoutDocument(layout: layout)
        
        connectToSimulator(doc: doc) { }
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let train = layout.trains[0]
        let ol1 = layout.block(named: "OL1")
        train.blockId = ol1.id
        ol1.train = .init(train.id, .next)

        // Ensure the turnouts are properly set
        layout.turnout(named: "E.1").setState(.straight)
        layout.turnout(named: "D.1").setState(.straight)

        let fa = layout.feedback(for: Identifier<Feedback>(uuid: "OL1.2"))!
        let fb = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.1"))!
        let fc = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.2"))!

        let step = 10
        
        train.speed.speedTable[step] = .init(steps: SpeedStep(value: UInt16(step)), speed: nil)
        XCTAssertNil(train.speed.speedTable[step].speed)

        let sm = TrainSpeedMeasurement(layout: layout, executor: doc.layoutController, interface: doc.interface, train: train,
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

        doc.simulator.setFeedback(feedback: fa, value: 1)

        wait(for: [feedbackAExpectation], timeout: 5.0)

        doc.simulator.setFeedback(feedback: fa, value: 0)
        doc.simulator.setFeedback(feedback: fb, value: 1)

        wait(for: [feedbackBExpectation], timeout: 5.0)

        doc.simulator.setFeedback(feedback: fb, value: 0)

        doc.simulator.triggerFeedback(feedback: fc)

        wait(for: [callbackExpectation], timeout: 5.0)

        XCTAssertEqual(expectedInfoArray.count, 0, "Expected steps are \(expectedInfoArray)")
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
        
        // TODO: use the same method as defined elsewhere
        func wait(for block: () -> Bool, timeout: TimeInterval) {
            let current = RunLoop.current
            let startTime = Date()
            while !block() {
                current.run(until: Date(timeIntervalSinceNow: 0.001))
                if Date().timeIntervalSince(startTime) >= timeout {
                    XCTFail("Time out")
                    break
                }
            }
        }

    }
    
    func testMeasureTwoStep() throws {
        let layout = LayoutComplex().newLayout()
        let doc = LayoutDocument(layout: layout)
        
        connectToSimulator(doc: doc) { }
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let train = layout.trains[0]
        let ol1 = layout.block(named: "OL1")
        train.blockId = ol1.id
        ol1.train = .init(train.id, .next)

        // Ensure the turnouts are properly set
        layout.turnout(named: "E.1").setState(.straight)
        layout.turnout(named: "D.1").setState(.straight)
        layout.turnout(named: "A.34").setState(.straight01)

        let fa = layout.feedback(for: Identifier<Feedback>(uuid: "OL1.2"))!
        let fb = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.1"))!
        let fc = layout.feedback(for: Identifier<Feedback>(uuid: "OL2.2"))!

        let step1 = 10
        let step2 = 20

        train.speed.speedTable[step1] = .init(steps: SpeedStep(value: UInt16(step1)), speed: nil)
        train.speed.speedTable[step2] = .init(steps: SpeedStep(value: UInt16(step2)), speed: nil)
        XCTAssertNil(train.speed.speedTable[step1].speed)
        XCTAssertNil(train.speed.speedTable[step2].speed)

        let sm = TrainSpeedMeasurement(layout: layout, executor: doc.layoutController, interface: doc.interface, train: train,
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
                
        doc.simulator.setFeedback(feedback: fa, value: 1)

        infoStepAsserter.assert(step: .feedbackA)

        doc.simulator.setFeedback(feedback: fa, value: 0)
        doc.simulator.setFeedback(feedback: fb, value: 1)

        infoStepAsserter.assert(step: .feedbackB)

        doc.simulator.setFeedback(feedback: fb, value: 0)
        doc.simulator.setFeedback(feedback: fc, value: 1)

        infoStepAsserter.assert(step: .feedbackC)
        
        doc.simulator.setFeedback(feedback: fc, value: 0)

        infoStepAsserter.assert(step: .trainStopped)
        infoStepAsserter.assert(step: .trainDirectionToggle)
        infoStepAsserter.assert(step: .trainStarted)

        doc.simulator.setFeedback(feedback: fc, value: 1)

        infoStepAsserter.assert(step: .feedbackC)

        doc.simulator.setFeedback(feedback: fc, value: 0)
        doc.simulator.setFeedback(feedback: fb, value: 1)

        infoStepAsserter.assert(step: .feedbackB)

        doc.simulator.setFeedback(feedback: fb, value: 0)
        doc.simulator.setFeedback(feedback: fa, value: 1)

        infoStepAsserter.assert(step: .feedbackA)
        
        doc.simulator.setFeedback(feedback: fa, value: 0)

        infoStepAsserter.assert(step: .trainStopped)
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
