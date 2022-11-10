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

/// This class tests the command sent by the simulator to BTrain, simulating commands made by the user on the Central Station 3
class MarklinSimulatorTests: XCTestCase {

    func testFeedbackCommand() {
        let doc = LayoutDocument(layout: Layout())
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        _ = doc.interface.callbacks.register(forFeedbackChange: { deviceId, contactId, value in
            e.fulfill()
        })
        
        doc.simulator.triggerFeedback(feedback: Feedback("foo", deviceID: 1, contactID: 2))
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testDirectionChange() {
        let doc = LayoutDocument(layout: LayoutLoop1().newLayout())
        // We must set the train in the layout for the direction to be
        // properly emitted from the simulator
        let train = doc.layout.trains[0]
        train.blockId = doc.layout.blockIds.first
        XCTAssertTrue(train.locomotive!.directionForward)
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        _ = doc.interface.callbacks.register(forDirectionChange: { address, decoderType, direction in
            XCTAssertFalse(direction == .forward)
            e.fulfill()
        })
        
        doc.simulator.setTrainDirection(train: doc.simulator.locomotives[0], directionForward: false)
        
        waitForExpectations(timeout: 1.0)
        
        XCTAssertFalse(train.locomotive!.directionForward)
    }

    func testTurnoutChange() {
        let doc = LayoutDocument(layout: Layout())
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        _ = doc.interface.callbacks.register(forTurnoutChange: { address, state, power, acknowledgement in
            XCTAssertEqual(2, state)
            e.fulfill()
        })
        
        doc.simulator.turnoutChanged(address: .init(7, .DCC), state: 2, power: 1)
        
        waitForExpectations(timeout: 1.0)
    }

    func testSpeedChange() {
        let doc = LayoutDocument(layout: LayoutLoop1().newLayout())
        let train = doc.layout.trains[0]
        train.blockId = doc.layout.blockIds.first
        train.speed!.actualKph = 70
        
        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let e = expectation(description: "callback")
        let directCommand = expectation(description: "directCommand")
        let acknowledgement = expectation(description: "acknowledgement")
        _ = doc.interface.callbacks.register(forSpeedChange: { address, decoderType, value, ack in
            if ack {
                acknowledgement.fulfill()
                XCTAssertEqual(358, value.value)
                e.fulfill()
            } else {
                directCommand.fulfill()
            }
        })
        
        doc.simulator.setTrainSpeed(train: doc.simulator.locomotives[0])
        
        wait(for: [directCommand, acknowledgement, e], timeout: 1.0, enforceOrder: true)
    }

    func testMultipleInstances() {
        let doc = LayoutDocument(layout: Layout())

        let s1 = MarklinCommandSimulator(layout: doc.layout, interface: doc.interface)
        let s2 = MarklinCommandSimulator(layout: doc.layout, interface: doc.interface)
        
        s1.start()
        s2.start()
        
        XCTAssertTrue(s1.started)
        XCTAssertTrue(s2.started)
    }
}
