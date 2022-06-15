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

class TrainHandlerManagedTests: BTTestCase {

    func testStateStopped() throws {
        let doc = LayoutDocument(layout: LayoutComplex().newLayout(), interface: MockCommandInterface())
        doc.layout.removeAllTrains()
        
        let train = doc.layout.train("16390")
        let ne1 = doc.layout.block(named: "NE1")
        
        try doc.layoutController.setTrainToBlock(train, ne1.id, position: .end, direction: .next)
        
        train.state = .stopped
        train.scheduling = .managed
        
        doc.layoutController.runControllers(.schedulingChanged(train: train))
        
        XCTAssertEqual(train.state, .stopped)
        XCTAssertEqual(train.scheduling, .unmanaged)
    }
    
    func testStateStoppedToRunning() throws {
        let doc = LayoutDocument(layout: LayoutComplex().newLayout(), interface: MockCommandInterface())
        doc.layout.removeAllTrains()
        
        let train = doc.layout.train("16390")
        let ne1 = doc.layout.block(named: "NE1")
        
        try doc.layoutController.setTrainToBlock(train, ne1.id, position: .end, direction: .next)

        try doc.layoutController.start(routeID: train.routeId, trainID: train.id)
                
        doc.layoutController.runControllers(.schedulingChanged(train: train))
        
        doc.layout.turnouts.forEach { turnout in
            turnout.actualState = turnout.requestedState
        }
        doc.layoutController.runControllers(drain: true)
        
        XCTAssertEqual(train.state, .running)
        XCTAssertEqual(train.scheduling, .managed)
    }

}
