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

class TurnoutTests: XCTestCase {

    func testCodable() throws {
        let t1 = Turnout(name: "1")
        t1.category = .doubleSlip2
        t1.address = .init(1, .MM)
        t1.address2 = .init(2, .MM)
        t1.requestedState = .straight01
        t1.center = .init(x: 7.5, y: 8.5)
        t1.rotationAngle = 90
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(t1)

        let decoder = JSONDecoder()
        let t2 = try decoder.decode(Turnout.self, from: data)
        
        XCTAssertTrue(t1.doubleAddress)
        XCTAssertTrue(t2.doubleAddress)
        XCTAssertEqual(t1.id, t2.id)
        XCTAssertEqual(t1.category, t2.category)
        XCTAssertEqual(t1.address, t2.address)
        XCTAssertEqual(t1.address2, t2.address2)
        XCTAssertEqual(t1.requestedState, t2.requestedState)
        XCTAssertEqual(t1.center, t2.center)
        XCTAssertEqual(t1.rotationAngle, t2.rotationAngle)
    }

    func testSingleLeftSockets() {
        let t1 = Turnout.singleLeft()
        
        XCTAssertEqual(t1.socket0, Socket.turnout(t1.id, socketId: 0))
        XCTAssertEqual(t1.socket1, Socket.turnout(t1.id, socketId: 1))
        XCTAssertEqual(t1.socket2, Socket.turnout(t1.id, socketId: 2))
                        
        XCTAssertEqual(t1.sockets(from: 0), [1, 2])
        XCTAssertEqual(t1.sockets(from: 1), [0])
        XCTAssertEqual(t1.sockets(from: 2), [0])
        XCTAssertEqual(t1.sockets(from: 3), [])
        
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 1), .straight)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 2), .branchLeft)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 0), .straight)
        XCTAssertEqual(t1.state(fromSocket: 2, toSocket: 0), .branchLeft)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 3), .invalid)
    }

    func testSingleRightSockets() {
        let t1 = Turnout.singleRight()

        XCTAssertEqual(t1.socket0, Socket.turnout(t1.id, socketId: 0))
        XCTAssertEqual(t1.socket1, Socket.turnout(t1.id, socketId: 1))
        XCTAssertEqual(t1.socket2, Socket.turnout(t1.id, socketId: 2))
                        
        XCTAssertEqual(t1.sockets(from: 0), [1, 2])
        XCTAssertEqual(t1.sockets(from: 1), [0])
        XCTAssertEqual(t1.sockets(from: 2), [0])
        XCTAssertEqual(t1.sockets(from: 3), [])
        
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 1), .straight)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 2), .branchRight)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 0), .straight)
        XCTAssertEqual(t1.state(fromSocket: 2, toSocket: 0), .branchRight)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 3), .invalid)
    }
    
    func testCrossingSockets() {
        let t1 = Turnout.doubleSlip2()

        XCTAssertEqual(t1.socket0, Socket.turnout(t1.id, socketId: 0))
        XCTAssertEqual(t1.socket1, Socket.turnout(t1.id, socketId: 1))
        XCTAssertEqual(t1.socket2, Socket.turnout(t1.id, socketId: 2))
        XCTAssertEqual(t1.socket3, Socket.turnout(t1.id, socketId: 3))
        
        XCTAssertEqual(t1.sockets(from: 0), [1, 3])
        XCTAssertEqual(t1.sockets(from: 1), [0, 2])
        XCTAssertEqual(t1.sockets(from: 2), [1, 3])
        XCTAssertEqual(t1.sockets(from: 3), [0, 2])
        XCTAssertEqual(t1.sockets(from: 4), [])
        
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 1), .straight01)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 0), .straight01)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 3), .branch03)
        XCTAssertEqual(t1.state(fromSocket: 3, toSocket: 0), .branch03)
        XCTAssertEqual(t1.state(fromSocket: 2, toSocket: 3), .straight23)
        XCTAssertEqual(t1.state(fromSocket: 3, toSocket: 2), .straight23)
        XCTAssertEqual(t1.state(fromSocket: 2, toSocket: 1), .branch21)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 2), .branch21)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 2), .invalid)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 3), .invalid)
    }

    func testThreewaySockets() {
        let t1 = Turnout.threeWay()

        XCTAssertEqual(t1.socket0, Socket.turnout(t1.id, socketId: 0))
        XCTAssertEqual(t1.socket1, Socket.turnout(t1.id, socketId: 1))
        XCTAssertEqual(t1.socket2, Socket.turnout(t1.id, socketId: 2))
        XCTAssertEqual(t1.socket3, Socket.turnout(t1.id, socketId: 3))

        XCTAssertEqual(t1.socket0, t1.socket(0))
        XCTAssertEqual(t1.socket1, t1.socket(1))
        XCTAssertEqual(t1.socket2, t1.socket(2))
        XCTAssertEqual(t1.socket3, t1.socket(3))

        XCTAssertEqual(t1.sockets(from: 0), [1, 2, 3])
        XCTAssertEqual(t1.sockets(from: 1), [0])
        XCTAssertEqual(t1.sockets(from: 2), [0])
        XCTAssertEqual(t1.sockets(from: 3), [0])
        XCTAssertEqual(t1.sockets(from: 4), [])
        
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 1), .straight)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 0), .straight)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 2), .branchRight)
        XCTAssertEqual(t1.state(fromSocket: 2, toSocket: 0), .branchRight)
        XCTAssertEqual(t1.state(fromSocket: 0, toSocket: 3), .branchLeft)
        XCTAssertEqual(t1.state(fromSocket: 3, toSocket: 0), .branchLeft)
        XCTAssertEqual(t1.state(fromSocket: 1, toSocket: 3), .invalid)
    }

    func testSingleLeftStateSockets() {
        let t1 = Turnout.singleLeft()
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .straight), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .straight), t1.socket0.socketId)
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .branchLeft), t1.socket2.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .branchLeft), t1.socket0.socketId)
    }

    func testSingleRightStateSockets() {
        let t1 = Turnout.singleRight()

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .straight), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .straight), t1.socket0.socketId)
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .branchRight), t1.socket2.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .branchRight), t1.socket0.socketId)
    }

    func testThreewayStateSockets() {
        let t1 = Turnout.threeWay()
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .straight), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .straight), t1.socket0.socketId)
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .branchRight), t1.socket2.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .branchRight), t1.socket0.socketId)
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .branchLeft), t1.socket3.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket3.socketId!, withState: .branchLeft), t1.socket0.socketId)
    }

    func testDoubleSlipStateSockets() {
        let t1 = Turnout.doubleSlip()
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .straight), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .straight), t1.socket0.socketId)

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .straight), t1.socket3.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket3.socketId!, withState: .straight), t1.socket2.socketId)

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .branch), t1.socket3.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket3.socketId!, withState: .branch), t1.socket0.socketId)

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .branch), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .branch), t1.socket2.socketId)
    }

    func testDoubleSlip2StateSockets() {
        let t1 = Turnout.doubleSlip2()
        
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .straight01), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .straight01), t1.socket0.socketId)

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .straight23), t1.socket3.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket3.socketId!, withState: .straight23), t1.socket2.socketId)

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket0.socketId!, withState: .branch03), t1.socket3.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket3.socketId!, withState: .branch03), t1.socket0.socketId)

        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket2.socketId!, withState: .branch21), t1.socket1.socketId)
        XCTAssertEqual(t1.socketId(fromSocketId: t1.socket1.socketId!, withState: .branch21), t1.socket2.socketId)
    }

    func testSingleLeftStates() {
        let t1 = Turnout.singleLeft()
        XCTAssertEqual(t1.allStates, [.straight, .branchLeft])
        
        XCTAssertEqual(t1.nextState, .branchLeft)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branchLeft)
        XCTAssertEqual(t1.requestedStateValue, 0)

        XCTAssertEqual(t1.nextState, .straight)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .straight)
        XCTAssertEqual(t1.requestedStateValue, 1)
        
        t1.requestedState = .branchRight
        XCTAssertEqual(t1.nextState, .invalid)
        XCTAssertEqual(t1.requestedStateValue, 0)
    }

    func testSingleRightStates() {
        let t1 = Turnout.singleRight()
        XCTAssertEqual(t1.allStates, [.straight, .branchRight])
        
        XCTAssertEqual(t1.nextState, .branchRight)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branchRight)
        XCTAssertEqual(t1.requestedStateValue, 0)

        XCTAssertEqual(t1.nextState, .straight)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .straight)
        XCTAssertEqual(t1.requestedStateValue, 1)

        t1.requestedState = .branchLeft
        XCTAssertEqual(t1.nextState, .invalid)
        XCTAssertEqual(t1.requestedStateValue, 0)
    }

    func testDoubleSlipStates() {
        let t1 = Turnout.doubleSlip()
        XCTAssertEqual(t1.allStates, [.straight, .branch])
        
        XCTAssertEqual(t1.nextState, .branch)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branch)
        XCTAssertEqual(t1.requestedStateValue, 0)

        XCTAssertEqual(t1.nextState, .straight)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .straight)
        XCTAssertEqual(t1.requestedStateValue, 1)
    }

    func testDoubleSlip2ToggleToNextState() {
        let t1 = Turnout.doubleSlip2()
        XCTAssertEqual(t1.allStates, [.straight01, .straight23, .branch03, .branch21])
        
        XCTAssertEqual(t1.nextState, .straight23)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .straight23)
        XCTAssertEqual(t1.requestedStateValue, 0)

        XCTAssertEqual(t1.nextState, .branch03)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branch03)
        XCTAssertEqual(t1.requestedStateValue, 1)

        XCTAssertEqual(t1.nextState, .branch21)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branch21)
        XCTAssertEqual(t1.requestedStateValue, 2)

        XCTAssertEqual(t1.nextState, .straight01)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .straight01)
        XCTAssertEqual(t1.requestedStateValue, 3)

        t1.requestedState = .branchLeft
        XCTAssertEqual(t1.nextState, .invalid)
        XCTAssertEqual(t1.requestedStateValue, 0)
    }

    func testThreewayStates() {
        let t1 = Turnout.threeWay()
        XCTAssertEqual(t1.allStates, [.straight, .branchLeft, .branchRight])
        
        XCTAssertEqual(t1.nextState, .branchLeft)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branchLeft)
        XCTAssertEqual(t1.requestedStateValue, 2)

        XCTAssertEqual(t1.nextState, .branchRight)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .branchRight)
        XCTAssertEqual(t1.requestedStateValue, 1)

        XCTAssertEqual(t1.nextState, .straight)
        t1.toggleToNextState()
        XCTAssertEqual(t1.requestedState, .straight)
        XCTAssertEqual(t1.requestedStateValue, 3)

        t1.requestedState = .branch21
        XCTAssertEqual(t1.nextState, .invalid)
        XCTAssertEqual(t1.requestedStateValue, 0)
    }

    func testSafeSetState() {
        let t1 = Turnout.doubleSlip2()
        XCTAssertEqual(.straight01, t1.requestedState)

        t1.setStateSafe(.branch03)
        XCTAssertEqual(.branch03, t1.requestedState)
        
        t1.reserved = .init(train: Identifier<Train>(uuid: "12"), sockets: nil)
        t1.setStateSafe(.straight01)
        XCTAssertEqual(.branch03, t1.requestedState)
        
        t1.reserved = nil
        t1.setStateSafe(.straight01)
        XCTAssertEqual(.straight01, t1.requestedState)
    }
    
    func testSingleLeftCommand() {
        let t = Turnout.singleLeft()
        
        var cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        
        t.requestedState = .branchLeft
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 0)
    }

    func testSingleRightCommand() {
        let t = Turnout.singleRight()

        var cmds = t.requestedStateCommands(power: 0x1)
        XCTAssertEqual(cmds.count, 1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        
        t.requestedState = .branchRight
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 0)
    }

    func testDoubleSlipCommands() {
        let t = Turnout.doubleSlip()
        
        var cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        
        t.requestedState = .branch
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 0)
    }

    func testDoubleSlip2Commands() {
        let t = Turnout.doubleSlip2()
        
        t.requestedState = .straight01
        var cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 1)
        
        t.requestedState = .straight23
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 0)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 0)
        
        t.requestedState = .branch03
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 0)
        
        t.requestedState = .branch21
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 0)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 1)
    }
    
    func testDoubleSlip2States() {
        let t = Turnout.doubleSlip2()

        assertDoubleSlip2(t, .straight01, .straight, [1, 1], .branch03)
        assertDoubleSlip2(t, .straight23, .straight01, [0, 0], .branch21)
        assertDoubleSlip2(t, .branch03, .straight23, [1, 0], .branch03)
        assertDoubleSlip2(t, .branch21, .branch03, [0, 1], .straight23)
        assertDoubleSlip2(t, .straight01, .branch21, [1, 1], .straight01)
    }
    
    private func assertDoubleSlip2(_ t: Turnout, _ requestedState: Turnout.State, _ actualState: Turnout.State, _ values: [UInt8], _ intermediateActualState: Turnout.State) {
        t.requestedState = requestedState
        XCTAssertEqual(t.requestedState, requestedState)
        XCTAssertEqual(t.actualState, actualState)
        
        t.setActualState(value: values[0], for: t.address.actualAddress)
        XCTAssertEqual(t.requestedState, requestedState)
        XCTAssertEqual(t.actualState, intermediateActualState)

        t.setActualState(value: values[1], for: t.address2.actualAddress)
        XCTAssertEqual(t.requestedState, requestedState)
        XCTAssertEqual(t.actualState, requestedState)
    }
    
    func testFindTurnoutsWith2Addresses() {
        let t1 = Turnout.doubleSlip2()
        let t2 = Turnout.doubleSlip2()
        t2.address = .init(10, .MM)
        t2.address2 = .init(20, .MM)

        let turnouts = [t1, t2]
        
        XCTAssertEqual(turnouts.find(address: t1.address), t1)
        XCTAssertEqual(turnouts.find(address: t1.address2), t1)
        
        XCTAssertEqual(turnouts.find(address: t2.address), t2)
        XCTAssertEqual(turnouts.find(address: t2.address2), t2)
    }
    
    func testThreewayCommands() {
        let t = Turnout.threeWay()
        
        var cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 1)
                
        t.requestedState = .branchLeft
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 0)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 1)
        
        t.requestedState = .branchRight
        cmds = t.requestedStateCommands(power: 0x1)
        assertTurnout(cmd: cmds[0], expectedAddress: 1, expectedPower: 1, expectedStateValue: 1)
        assertTurnout(cmd: cmds[1], expectedAddress: 2, expectedPower: 1, expectedStateValue: 0)
    }
    
    func assertTurnout(cmd: Command, expectedAddress: UInt32, expectedPower: UInt8, expectedStateValue: UInt8) {
        if case .turnout(address: let address, state: let state, power: let power, priority: let priority, descriptor: _) = cmd {
            XCTAssertEqual(priority, .normal)
            XCTAssertEqual(address.address, expectedAddress)
            XCTAssertEqual(power, expectedPower)
            XCTAssertEqual(state, expectedStateValue)
        }
    }

}
