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

/// This class tests the commands sent by BTrain towards the Digital Controller, in this case, the simulator.
class CommandInterfaceTests: XCTestCase {
    
    func testGoAndStop() {
        let doc = LayoutDocument(layout: Layout())
        XCTAssertFalse(doc.simulator.enabled)
        
        connectToSimulator(doc: doc, enable: false)
        defer {
            disconnectFromSimulator(doc: doc, disable: false)
        }
        
        let enabledExpectation = XCTestExpectation(description: "enabled")
        let disabledExpectation = XCTestExpectation(description: "disable")
        let cancellable = doc.simulator.$enabled.dropFirst().sink { value in
            if value {
                enabledExpectation.fulfill()
            } else {
                disabledExpectation.fulfill()
            }
        }

        let goExpectation = XCTestExpectation(description: "go")
        let stopExpectation = XCTestExpectation(description: "stop")
        
        doc.interface.execute(command: .go()) {
            goExpectation.fulfill()
            doc.interface.execute(command: .stop()) {
                stopExpectation.fulfill()
            }
        }

        wait(for: [enabledExpectation, goExpectation, disabledExpectation, stopExpectation], timeout: 1.0, enforceOrder: true)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testSpeedCommand() {
        let doc = LayoutDocument(layout: Layout())
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        doc.interface.callbacks.register(forSpeedChange: { address, decoderType, value, ack in
            XCTAssertTrue(ack)
            XCTAssertEqual(18, value.value)
            e.fulfill()
        })
        
        let c = expectation(description: "completion")
        doc.interface.execute(command: .speed(address: 7, decoderType: .MFX, value: .init(value: 18), priority: .normal, descriptor: nil)) {
            c.fulfill()
        }
        
        wait(for: [c, e], timeout: 1.0, enforceOrder: true)
    }

    func testDirectionCommand() {
        let doc = LayoutDocument(layout: Layout())
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        _ = doc.interface.callbacks.register(forDirectionChange: { address, decoderType, direction in
            XCTAssertTrue(direction == .forward)
            e.fulfill()
        })
        
        let c = expectation(description: "completion")
        doc.interface.execute(command: .direction(address: 7, decoderType: .MFX, direction: .forward, priority: .normal, descriptor: nil)) {
            c.fulfill()
        }
        
        wait(for: [c, e], timeout: 1.0, enforceOrder: true)
    }

    func testQueryDirectionCommand() {
        let doc = LayoutDocument(layout: LayoutLoop1().newLayout())
        // We must set the train in the layout for the direction to be
        // properly emitted from the simulator
        let train = doc.layout.trains[0]
        train.blockId = doc.layout.blockIds.first

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }
        
        let c = expectation(description: "completion")
        doc.interface.execute(command: .queryDirection(address: train.address, decoderType: train.decoder, priority: .normal, descriptor: nil)) {
            c.fulfill()
        }
        
        wait(for: [c], timeout: 1.0)
    }

    func testTurnoutCommand() {
        let doc = LayoutDocument(layout: Layout())
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        doc.interface.callbacks.register(forTurnoutChange: { address, state, power, acknowledgement in
            e.fulfill()
        })
        
        let c = expectation(description: "completion")
        doc.interface.execute(command: .turnout(address: .init(0, .DCC), state: 7, power: 1, priority: .normal, descriptor: nil)) {
            c.fulfill()
        }
        
        wait(for: [c, e], timeout: 1.0, enforceOrder: true)
    }

    func testDiscoverLocomotives() {
        let doc = LayoutDocument(layout: Layout())
        
        let completionExpectation = XCTestExpectation()
        connectToSimulator(doc: doc)

        let e = expectation(description: "callback")
        doc.interface.callbacks.register { locomotives in
            XCTAssertFalse(locomotives.isEmpty)
            e.fulfill()
        }
        
        doc.layoutController.discoverLocomotives(merge: false) {
            completionExpectation.fulfill()
        }

        wait(for: [e, completionExpectation], timeout: 1)

        defer {
            disconnectFromSimulator(doc: doc)
        }

        XCTAssertEqual(doc.layout.trains.count, 11)

        let loc1 = doc.layout.trains[0]
        XCTAssertEqual(loc1.name, "460 106-8 SBB")
        XCTAssertEqual(loc1.address, 0x6)
    }
    
    func testFeedbackCallbackOrdering() {
        let doc = LayoutDocument(layout: Layout())
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }
        
        let firstCallbackExpectation = XCTestExpectation(description: "first")
        let secondCallbackExpectation = XCTestExpectation(description: "second")
        
        let uuid1 = doc.interface.callbacks.register(forFeedbackChange: { deviceID,contactID,value in
            firstCallbackExpectation.fulfill()
        })
        let uuid2 = doc.interface.callbacks.register(forFeedbackChange: { deviceID,contactID,value in
            secondCallbackExpectation.fulfill()
        })

        let layout = LayoutComplex().newLayout()
        let f = layout.feedbacks[0]
        doc.simulator.triggerFeedback(feedback: f)
        
        wait(for: [firstCallbackExpectation, secondCallbackExpectation], timeout: 1.0, enforceOrder: true)
        
        doc.interface.callbacks.unregister(uuid: uuid1)
        doc.interface.callbacks.unregister(uuid: uuid2)
    }
    
    /// Ensures that converting a speed steps to a speed value works fine, including edge cases
    /// when the value is 0 or 1.
    func testSpeedStepToValueConversion() {
        let interface = MarklinInterface()

        for decoder in DecoderType.allCases {
            let maxSteps = UInt16(decoder.steps)
            assertSpeedStepToValue(requestedSteps: 0, convertedSteps: 0, interface: interface, decoder: decoder)
            assertSpeedStepToValue(requestedSteps: 1, convertedSteps: 1, interface: interface, decoder: decoder)
            assertSpeedStepToValue(requestedSteps: maxSteps, convertedSteps: maxSteps, interface: interface, decoder: decoder)
            assertSpeedStepToValue(requestedSteps: maxSteps*2, convertedSteps: maxSteps, interface: interface, decoder: decoder)
        }
    }
    
    /// Ensures that converting a speed value to a speed steps works fine, including edge cases
    /// when the value is 0 or 1.
    func testSpeedValueToStepConversion() {
        let interface = MarklinInterface()
        let maxValue = UInt16(MarklinInterface.maxCANSpeedValue)
        
        let convertedValues: [UInt16] = [72, 38, 36, 8, 33]
        
        for (index, decoder) in DecoderType.allCases.enumerated() {
            assertSpeedValueToStep(requestedValue: 0, convertedValue: 0, interface: interface, decoder: decoder)
            assertSpeedValueToStep(requestedValue: 1, convertedValue: convertedValues[index], interface: interface, decoder: decoder)
            assertSpeedValueToStep(requestedValue: maxValue, convertedValue: maxValue, interface: interface, decoder: decoder)
            assertSpeedValueToStep(requestedValue: maxValue*2, convertedValue: maxValue, interface: interface, decoder: decoder)
        }
    }

    private func assertSpeedValueToStep(requestedValue: UInt16, convertedValue: UInt16, interface: CommandInterface, decoder: DecoderType) {
        let steps = interface.speedSteps(for: SpeedValue(value: requestedValue), decoder: decoder)
        let value = interface.speedValue(for: steps, decoder: decoder)
        XCTAssertEqual(value.value, convertedValue)
    }
    
    private func assertSpeedStepToValue(requestedSteps: UInt16, convertedSteps: UInt16, interface: CommandInterface, decoder: DecoderType) {
        let value = interface.speedValue(for: SpeedStep(value: requestedSteps), decoder: decoder)
        let steps = interface.speedSteps(for: SpeedValue(value: value.value), decoder: decoder)
        XCTAssertEqual(steps.value, convertedSteps)
    }

}
