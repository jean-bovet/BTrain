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

/// This state machine processes a ``StateMachine/TrainEvent``.
///
/// The following rules are used for an event belonging to the same train:
/// - A position event triggers an update for the occupied and reserved blocks
/// - A scheduling event triggers an update in the reserved blocks
/// - A state event triggers an update of the state again
/// - A restart timer event triggers a route reset and an update in the reserved blocks
/// - A reserved blocks event triggers a state update
/// - A reserved blocks settled event update triggers a speed update
/// - A speed event triggers a state update
///
/// The following rules are used for an event belonging to another train:
/// - A reserved blocks event from another train triggers a reserved block update for this train
struct TrainEventStateMachine {
    let tsm = TrainStateStateMachine()

    func handle(trainEvent: StateMachine.TrainEvent, train: TrainControlling) throws -> StateMachine.TrainEvent? {
        if trainEvent.belongs(toTrain: train) {
            return try handleSameTrainEvent(trainEvent: trainEvent, train: train)
        } else {
            return try handleOtherTrainEvent(trainEvent: trainEvent, train: train)
        }
    }

    private func handleSameTrainEvent(trainEvent: StateMachine.TrainEvent, train: TrainControlling) throws -> StateMachine.TrainEvent? {
        switch trainEvent {
        case .position:
            if try train.updateOccupiedAndReservedBlocks() {
                return .reservedBlocksChanged(train)
            } else {
                // Note: when moving within a block, there might not always been an update
                // to the reserved block. In this case, let's make sure the train state is handled
                // in order to brake or stop the train within a block.
                if try tsm.handleTrainState(train: train) {
                    try adjustSpeed(ofTrain: train, stateChanged: true)
                    return .stateChanged(train)
                }
            }

        case .modeChanged:
            if train.mode == .managed {
                // Execute the functions associated with the starting route item
                // when the route is started
                train.executeFunctions()
                
                if try train.updateReservedBlocks() {
                    // Note: change the train direction is necessary after the necessary blocks
                    // have been reserved. Changing the direction will unblock the train which
                    // is going to be started automatically.
                    if train.shouldChangeDirection {
                        try train.changeDirection()
                    }

                    return .reservedBlocksChanged(train)
                }
            } else {
                if train.mode == .stopManaged || train.mode == .stopImmediatelyManaged, train.state == .stopped {
                    // Note: explicitly remove the reserved blocks when a stop is requested
                    // while the train is already stopped.
                    if try train.removeReservedBlocks() {
                        return .reservedBlocksChanged(train)
                    }
                }

                if try tsm.handleTrainState(train: train) {
                    try adjustSpeed(ofTrain: train, stateChanged: true)
                    return .stateChanged(train)
                }
            }

        case .stateChanged:
            // Note: do not remove the reserved blocks if they are still settling. The train
            // can be in the stopped state because the reserved blocks are still settling and
            // the train does not have enough free distance to move.
            if train.state == .stopped, !train.reservedBlocksSettling || train.mode == .unmanaged {
                if try train.removeReservedBlocks() {
                    return .reservedBlocksChanged(train)
                }
            }

            if try tsm.handleTrainState(train: train) {
                try adjustSpeed(ofTrain: train, stateChanged: true)
                return .stateChanged(train)
            }

        case .restartTimerFired:
            train.startedRouteIndex = train.currentRouteIndex
            if try !train.shouldStopInBlock(ignoreReservedBlocks: true) && train.updateReservedBlocks() {
                return .reservedBlocksChanged(train)
            }

        case .reservedBlocksChanged(_), .reservedBlocksSettledLengthChanged:
            if try tsm.handleTrainState(train: train) {
                try adjustSpeed(ofTrain: train, stateChanged: true)
                return .stateChanged(train)
            } else {
                try adjustSpeed(ofTrain: train, stateChanged: false)
            }

        case .speed:
            // Speed change can result in state change, for example when the speed reaches 0.
            if try tsm.handleTrainState(train: train) {
                try adjustSpeed(ofTrain: train, stateChanged: true)
                return .stateChanged(train)
            }
        }
        return nil
    }

    private func handleOtherTrainEvent(trainEvent: StateMachine.TrainEvent, train: TrainControlling) throws -> StateMachine.TrainEvent? {
        if case .reservedBlocksChanged = trainEvent, train.mode != .unmanaged {
            if try train.updateReservedBlocks() {
                return .reservedBlocksChanged(train)
            }
        }
        return nil
    }

    private func adjustSpeed(ofTrain train: TrainControlling, stateChanged: Bool) throws {
        if train.mode != .unmanaged {
            try train.adjustSpeed(stateChanged: stateChanged)
        }
    }
}

extension StateMachine.TrainEvent {
    /// Returns true if this event belongs to the specified train.
    /// - Parameter train: the train
    /// - Returns: true if the event belongs to the train
    func belongs(toTrain train: TrainControlling) -> Bool {
        switch self {
        case let .position(te):
            return te.id == train.id
        case let .speed(te):
            return te.id == train.id
        case let .modeChanged(te):
            return te.id == train.id
        case let .stateChanged(te):
            return te.id == train.id
        case let .restartTimerFired(te):
            return te.id == train.id
        case let .reservedBlocksChanged(te):
            return te.id == train.id
        case let .reservedBlocksSettledLengthChanged(te):
            return te.id == train.id
        }
    }
}
