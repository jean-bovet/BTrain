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

import Foundation

extension Turnout {
    static func states(for category: Category) -> [State] {
        switch category {
        case .singleLeft:
            return [.straight, .branchLeft]
        case .singleRight:
            return [.straight, .branchRight]
        case .threeWay:
            return [.straight, .branchLeft, .branchRight]
        case .doubleSlip:
            return [.straight, .branch]
        case .doubleSlip2:
            return [.straight01, .straight23, .branch03, .branch21]
        }
    }

    static func defaultState(for category: Category) -> State {
        switch category {
        case .singleLeft, .singleRight, .threeWay:
            return .straight

        case .doubleSlip:
            return .straight

        case .doubleSlip2:
            return .straight01
        }
    }

    // Returns all the possible states for the turnout
    var allStates: [State] {
        Turnout.states(for: category)
    }

    // Returns the next state the turnout will take when toggling between
    // the states - see toggle() method below.
    var nextState: State {
        switch category {
        case .singleLeft:
            switch requestedState {
            case .straight:
                return .branchLeft
            case .branchLeft:
                return .straight
            default:
                return .invalid
            }

        case .singleRight:
            switch requestedState {
            case .straight:
                return .branchRight
            case .branchRight:
                return .straight
            default:
                return .invalid
            }

        case .doubleSlip:
            switch requestedState {
            case .straight:
                return .branch
            case .branch:
                return .straight
            default:
                return .invalid
            }

        case .doubleSlip2:
            switch requestedState {
            case .straight01:
                return .straight23
            case .straight23:
                return .branch03
            case .branch03:
                return .branch21
            case .branch21:
                return .straight01
            default:
                return .invalid
            }

        case .threeWay:
            switch requestedState {
            case .straight:
                return .branchLeft
            case .branchRight:
                return .straight
            case .branchLeft:
                return .branchRight
            default:
                return .invalid
            }
        }
    }

    static var statesMap: [Turnout.Category: [Turnout.State: UInt8]] = [
        .singleLeft: [.straight: 1, .branchLeft: 0],
        .singleRight: [.straight: 1, .branchRight: 0],
        .doubleSlip: [.straight: 1, .branch: 0],
        .doubleSlip2: [.straight01: 3, .straight23: 0, .branch21: 2, .branch03: 1],
        .threeWay: [.straight: 3, .branchLeft: 2, .branchRight: 1],
    ]

    var requestedStateValue: UInt8 {
        stateValue(for: requestedState)
    }

    var actualStateValue: UInt8 {
        stateValue(for: actualState)
    }

    private func stateValue(for state: State) -> UInt8 {
        if let states = Turnout.statesMap[category] {
            return states[state] ?? 0
        } else {
            BTLogger.error("Unknown turnout category \(category)")
            return 0
        }
    }

    private func setActualState(for value: UInt8) {
        guard let states = Turnout.statesMap[category] else {
            BTLogger.error("Unknown turnout category \(category)")
            actualState = .invalid
            return
        }
        guard let state = states.first(where: { $0.value == value }) else {
            BTLogger.error("Unknown turnout state value \(value) for \(category)")
            actualState = .invalid
            return
        }
        actualState = state.key
    }

    // Return the socket reachable from the "fromSocket" given the specific "state"
    func socketId(fromSocketId: Int, withState state: State) -> Int? {
        let candidates = sockets(from: fromSocketId)
        for toSocket in candidates {
            let s = self.state(fromSocket: fromSocketId, toSocket: toSocket)
            if s == state {
                return toSocket
            }
        }
        return nil
    }

    // Use this method to set an individual turnout address's state.
    // This is only useful for double slip or threeway turnout with
    // two addresses, each corresponding to a single turnout in
    // the real layout.
    func setActualState(value state: UInt8, for stateAddress: UInt32) {
        if category == .doubleSlip2 || category == .threeWay {
            let actualValue = stateValue(for: actualState)
            if address2.actualAddress == stateAddress {
                let value1 = (actualValue & 0x01)
                let value2 = (state & 0x01) << 1
                setActualState(for: value1 | value2)
            } else if address.actualAddress == stateAddress {
                let value1 = (state & 0x01)
                let value2 = (actualValue & 0x02)
                setActualState(for: value1 | value2)
            }
        } else {
            setActualState(for: state)
        }
    }

    // Returns the command corresponding to
    // the state of the turnout.
    func requestedStateCommands(power: UInt8) -> [Command] {
        let stateValue = requestedStateValue
        if category == .doubleSlip2 || category == .threeWay {
            let value1 = (stateValue & 0x01)
            let value2 = (stateValue & 0x02) >> 1
            return [.turnout(address: address, state: value1, power: power),
                    .turnout(address: address2, state: value2, power: power)]
        } else {
            return [.turnout(address: address, state: stateValue, power: power)]
        }
    }

    func state(fromSocket: Int, toSocket: Int) -> State {
        switch category {
        case .singleLeft:
            switch (fromSocket, toSocket) {
            case (0, 1), (1, 0):
                return .straight
            case (0, 2), (2, 0):
                return .branchLeft
            default:
                return .invalid
            }

        case .singleRight:
            switch (fromSocket, toSocket) {
            case (0, 1), (1, 0):
                return .straight
            case (0, 2), (2, 0):
                return .branchRight
            default:
                return .invalid
            }

        case .doubleSlip:
            switch (fromSocket, toSocket) {
            case (0, 1), (1, 0):
                return .straight
            case (2, 3), (3, 2):
                return .straight
            case (0, 3), (3, 0):
                return .branch
            case (2, 1), (1, 2):
                return .branch
            default:
                return .invalid
            }

        case .doubleSlip2:
            switch (fromSocket, toSocket) {
            case (0, 1), (1, 0):
                return .straight01
            case (2, 3), (3, 2):
                return .straight23
            case (0, 3), (3, 0):
                return .branch03
            case (2, 1), (1, 2):
                return .branch21
            default:
                return .invalid
            }

        case .threeWay:
            switch (fromSocket, toSocket) {
            case (0, 1), (1, 0):
                return .straight
            case (0, 2), (2, 0):
                return .branchRight
            case (0, 3), (3, 0):
                return .branchLeft
            default:
                return .invalid
            }
        }
    }

    // Use this method to safely set the state
    func setStateSafe(_ state: State) {
        if reserved == nil {
            requestedState = state
        }
    }

    // Use this method to toggle to the next available
    // state of the turnout. This is mainly used by the
    // UX when the user click on the turnout and it rotates
    // over all its available states.
    func toggleToNextState() {
        setStateSafe(nextState)
    }
}
