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

class MarklinInterfaceTests: XCTestCase {
    
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
    
    func testGo() {
        XCTAssertFalse(simulator.enabled)
        
        let enabledExpectation = XCTestExpectation()
        let cancellable = simulator.$enabled.sink { value in
            if value {
                enabledExpectation.fulfill()
            }
        }

        mi.execute(command: .go()) {}
        
        wait(for: [enabledExpectation], timeout: ScheduledMessageQueue.DefaultDelay)
        
        XCTAssertTrue(simulator.enabled)
        XCTAssertNotNil(cancellable)
    }
    
    func testDiscoverLocomotives() {
        let doc = LayoutDocument(layout: Layout())
        
        let completionExpectation = XCTestExpectation()
        doc.connectToSimulator(enable: true) { error in
            doc.layoutController.discoverLocomotives(merge: false) {
                completionExpectation.fulfill()
            }
        }
        
        wait(for: [completionExpectation], timeout: 1)

        doc.disconnect()

        XCTAssertEqual(doc.layout.trains.count, 11)

        let loc1 = doc.layout.trains[0]
        XCTAssertEqual(loc1.name, "460 106-8 SBB")
        XCTAssertEqual(loc1.address, 0x6)
    }
    
    func testCallbackOrdering() {
        let firstCallbackExpectation = XCTestExpectation()
        let secondCallbackExpectation = XCTestExpectation()

        let uuid1 = mi.register(forFeedbackChange: { deviceID,contactID,value in
            firstCallbackExpectation.fulfill()
        })
        let uuid2 = mi.register(forFeedbackChange: { deviceID,contactID,value in
            secondCallbackExpectation.fulfill()
        })

        XCTAssertEqual(mi.feedbackChangeCallbacks.count, 2)

        let layout = LayoutComplex().newLayout()
        let f = layout.feedbacks[0]
        simulator.triggerFeedback(feedback: f)
        
        wait(for: [firstCallbackExpectation, secondCallbackExpectation], timeout: 1.0, enforceOrder: true)
        
        mi.unregister(uuid: uuid1)
        mi.unregister(uuid: uuid2)

        XCTAssertEqual(mi.feedbackChangeCallbacks.count, 0)
    }
}
