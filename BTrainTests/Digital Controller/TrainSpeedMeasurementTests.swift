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

class TrainSpeedMeasurementTests: BTTestCase {
    func testCancelMeasure() throws {
        let layout = LayoutComplex().newLayout()
        let doc = LayoutDocument(layout: layout)

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let loc = layout.locomotives[0]
        let fa = layout.feedbacks[Identifier<Feedback>(uuid: "OL1.2")]!
        let fb = layout.feedbacks[Identifier<Feedback>(uuid: "OL2.1")]!
        let fc = layout.feedbacks[Identifier<Feedback>(uuid: "OL2.2")]!

        let step = 10

        let sm = LocomotiveSpeedMeasurement(layout: layout, executor: doc.layoutController, interface: doc.interface, loc: loc,
                                            speedEntries: [UInt16(step)],
                                            feedbackA: fa.id, feedbackB: fb.id, feedbackC: fc.id,
                                            distanceAB: 95, distanceBC: 18,
                                            simulator: true)

        let trainStartedExpectation = expectation(description: "TrainStarted")

        sm.start { info in
            if info.step == .locomotiveStarted {
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
        let doc = LayoutDocument(layout: layout)

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let loc = layout.locomotives[0]

        let fa = layout.feedbacks[Identifier<Feedback>(uuid: "OL1.2")]!
        let fb = layout.feedbacks[Identifier<Feedback>(uuid: "OL2.1")]!
        let fc = layout.feedbacks[Identifier<Feedback>(uuid: "OL2.2")]!

        let step = 10

        loc.speed.speedTable[step] = .init(steps: SpeedStep(value: UInt16(step)), speed: nil)
        XCTAssertNil(loc.speed.speedTable[step].speed)

        let sm = LocomotiveSpeedMeasurement(layout: layout, executor: doc.layoutController, interface: doc.interface, loc: loc,
                                            speedEntries: [UInt16(step)],
                                            feedbackA: fa.id, feedbackB: fb.id, feedbackC: fc.id,
                                            distanceAB: 95, distanceBC: 18,
                                            simulator: true)

        var expectedInfoArray: [LocomotiveSpeedMeasurement.CallbackStep] = [.locomotiveStarted, .feedbackA, .feedbackB, .feedbackC, .locomotiveStopped, .locomotiveDirectionToggle, .done]

        let callbackExpectation = expectation(description: "Callback")
        callbackExpectation.expectedFulfillmentCount = expectedInfoArray.count

        let trainStartedExpectation = expectation(description: "TrainStarted")
        let feedbackAExpectation = expectation(description: "Feedback A")
        let feedbackBExpectation = expectation(description: "Feedback B")

        sm.start { info in
            XCTAssertEqual(info.progress, 1)
            let expectedInfo = expectedInfoArray.removeFirst()
            XCTAssertEqual(expectedInfo, info.step)
            if info.step == .locomotiveStarted {
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
        XCTAssertEqual(loc.speed.speedTable[step].steps.value, UInt16(step))
        XCTAssertNotNil(loc.speed.speedTable[step].speed)
        XCTAssertEqual(sm.feedbackMonitor.pendingRequestCount, 0)
    }

    final class InfoStepAsserter {
        var actualInfoStepArray = [LocomotiveSpeedMeasurement.CallbackStep]()

        func assert(step: LocomotiveSpeedMeasurement.CallbackStep) {
            wait(for: {
                if actualInfoStepArray.isEmpty {
                    return false
                } else {
                    return actualInfoStepArray.removeFirst() == step
                }
            }, timeout: 2.0)
        }
    }

    func testMeasureTwoStep() throws {
        let layout = LayoutComplex().newLayout()
        let doc = LayoutDocument(layout: layout)

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let loc = layout.locomotives[0]

        let fa = layout.feedbacks[Identifier<Feedback>(uuid: "OL1.2")]!
        let fb = layout.feedbacks[Identifier<Feedback>(uuid: "OL2.1")]!
        let fc = layout.feedbacks[Identifier<Feedback>(uuid: "OL2.2")]!

        let step1 = 10
        let step2 = 20

        loc.speed.speedTable[step1] = .init(steps: SpeedStep(value: UInt16(step1)), speed: nil)
        loc.speed.speedTable[step2] = .init(steps: SpeedStep(value: UInt16(step2)), speed: nil)
        XCTAssertNil(loc.speed.speedTable[step1].speed)
        XCTAssertNil(loc.speed.speedTable[step2].speed)

        let sm = LocomotiveSpeedMeasurement(layout: layout, executor: doc.layoutController, interface: doc.interface, loc: loc,
                                            speedEntries: [UInt16(step1), UInt16(step2)],
                                            feedbackA: fa.id, feedbackB: fb.id, feedbackC: fc.id,
                                            distanceAB: 95, distanceBC: 18, simulator: true)

        var expectedInfoArray: [LocomotiveSpeedMeasurement.CallbackStep] = [.locomotiveStarted, .feedbackA, .feedbackB, .feedbackC, .locomotiveStopped, .locomotiveDirectionToggle,
                                                                            .locomotiveStarted, .feedbackC, .feedbackB, .feedbackA, .locomotiveStopped, .locomotiveDirectionToggle, .done]

        let callbackExpectation = expectation(description: "Callback")
        callbackExpectation.expectedFulfillmentCount = expectedInfoArray.count

        let infoStepAsserter = InfoStepAsserter()

        sm.start { info in
            callbackExpectation.fulfill()

            let expectedInfo = expectedInfoArray.removeFirst()
            infoStepAsserter.actualInfoStepArray.append(info.step)
            XCTAssertEqual(expectedInfo, info.step)
        }

        infoStepAsserter.assert(step: .locomotiveStarted)

        doc.simulator.setFeedback(feedback: fa, value: 1)

        infoStepAsserter.assert(step: .feedbackA)

        doc.simulator.setFeedback(feedback: fa, value: 0)
        doc.simulator.setFeedback(feedback: fb, value: 1)

        infoStepAsserter.assert(step: .feedbackB)

        doc.simulator.setFeedback(feedback: fb, value: 0)
        doc.simulator.setFeedback(feedback: fc, value: 1)

        infoStepAsserter.assert(step: .feedbackC)

        doc.simulator.setFeedback(feedback: fc, value: 0)

        infoStepAsserter.assert(step: .locomotiveStopped)
        infoStepAsserter.assert(step: .locomotiveDirectionToggle)
        infoStepAsserter.assert(step: .locomotiveStarted)

        doc.simulator.setFeedback(feedback: fc, value: 1)

        infoStepAsserter.assert(step: .feedbackC)

        doc.simulator.setFeedback(feedback: fc, value: 0)
        doc.simulator.setFeedback(feedback: fb, value: 1)

        infoStepAsserter.assert(step: .feedbackB)

        doc.simulator.setFeedback(feedback: fb, value: 0)
        doc.simulator.setFeedback(feedback: fa, value: 1)

        infoStepAsserter.assert(step: .feedbackA)

        doc.simulator.setFeedback(feedback: fa, value: 0)

        infoStepAsserter.assert(step: .locomotiveStopped)
        infoStepAsserter.assert(step: .locomotiveDirectionToggle)
        infoStepAsserter.assert(step: .done)

        XCTAssertEqual(expectedInfoArray.count, 0)

        wait(for: [callbackExpectation], timeout: 5.0)

        XCTAssertEqual(loc.speed.speedTable[step1].steps.value, UInt16(step1))
        XCTAssertNotNil(loc.speed.speedTable[step1].speed)

        XCTAssertEqual(loc.speed.speedTable[step2].steps.value, UInt16(step2))
        XCTAssertNotNil(loc.speed.speedTable[step2].speed)

        XCTAssertNotEqual(loc.speed.speedTable[step1].steps.value, loc.speed.speedTable[step2].steps.value)
        XCTAssertEqual(sm.feedbackMonitor.pendingRequestCount, 0)
    }
}
