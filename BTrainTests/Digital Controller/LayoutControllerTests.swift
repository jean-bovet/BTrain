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

class LayoutControllerTests: BTTestCase {
    func testTurnoutListener() throws {
        let layout = LayoutComplexLoop().newLayout()
        let interface = MarklinInterface()
        let c = LayoutController(layout: layout, switchboard: nil, interface: interface, functionCatalog: nil)
        c.registerForTurnoutChange()

        let t1 = layout.turnouts[0]
        t1.setActualState(value: 0, for: t1.address.actualAddress)
        XCTAssertEqual(t1.actualState, .branchLeft)

        let m = MarklinCANMessageFactory.accessory(addr: t1.address.actualAddress, state: 1, power: 1)
        interface.onMessage(msg: m)

        XCTAssertEqual(t1.actualState, .branchLeft)

        interface.onMessage(msg: m.ack)
        XCTAssertEqual(t1.actualState, .straight)
    }

    /// Ensure that a train that is running cannot have its route changed
    func testPrepareRouteWhileRunning() throws {
        let doc = LayoutDocument(layout: LayoutComplexLoop().newLayout())
        let t = doc.layout.trains[0]

        t.scheduling = .unmanaged
        try doc.layoutController.prepare(routeID: t.routeId, trainID: t.id)

        t.scheduling = .managed
        XCTAssertThrowsError(try doc.layoutController.prepare(routeID: t.routeId, trainID: t.id))
    }

    /// Ensures that when the Digital Controller is "off" and a turnout command it sent, to which no acknowledgement will be returned,
    /// that once the Digital Controller is turned "on" again, a subsequent turnout command it properly executed. This test ensures
    /// the scheduled queue used by the ``LayoutTurnoutManager`` is correctly reset and able to process new commands.
    func testChangeTurnoutAndStopCommand() throws {
        let doc = LayoutDocument(layout: LayoutComplexLoop().newLayout())

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let t1 = doc.layout.turnouts[0]
        t1.category = .singleLeft
        t1.actualState = .straight

        // Send a turnout command while the Digital Controller is "on"
        changeTurnout(doc, t1, .branchLeft)

        // Stop the Digital Controller
        stop(doc: doc)

        t1.requestedState = .straight
        doc.layoutController.sendTurnoutState(turnout: t1) { _ in
            // This completion block is going to be called after the go command is processed below,
            // because the network completion block is going to be invoked only when the command
            // is "turned on" again with the go command.
        }

        wait(for: 0.5)

        XCTAssertEqual(t1.actualState, .branchLeft)
        XCTAssertFalse(t1.settled)

        // Enable the Digital Controller again
        go(doc: doc)

        XCTAssertEqual(t1.actualState, .branchLeft)
        XCTAssertFalse(t1.settled)

        // Send another turnout command while the Digital Controller is "on" and check that it worked
        changeTurnout(doc, t1, .straight)
    }

    private func changeTurnout(_ doc: LayoutDocument, _ turnout: Turnout, _ state: Turnout.State) {
        let change2 = expectation(description: "change2")

        turnout.requestedState = state

        doc.layoutController.sendTurnoutState(turnout: turnout) { completed in
            XCTAssertTrue(completed)
            change2.fulfill()
        }

        wait(for: [change2], timeout: 0.5)

        XCTAssertEqual(turnout.actualState, state)
        XCTAssertTrue(turnout.settled)
    }
}
