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
        case .position(_):            
            if try train.updateOccupiedAndReservedBlocks() {
                return .reservedBlocksChanged(train)
            } else {
                // Note: when moving within a block, there might not always been an update
                // to the reserved block. In this case, let's make sure the train state is handled
                // in order to brake or stop the train within a block.
                if tsm.handleTrainState(train: train) {
                    adjustSpeed(ofTrain: train, stateChanged: true)
                    return .stateChanged(train)
                }
            }
            
        case .modeChanged(_):
            if train.mode == .managed {
                if try train.updateReservedBlocks() {
                    return .reservedBlocksChanged(train)
                }
            } else {
                if train.mode == .stopManaged && train.state == .stopped {
                    // Note: explicitly remove the reserved blocks when a stop is requested
                    // while the train is already stopped.
                    if try train.removeReservedBlocks() {
                        return .reservedBlocksChanged(train)
                    }
                }
                
                if tsm.handleTrainState(train: train) {
                    adjustSpeed(ofTrain: train, stateChanged: true)
                    return .stateChanged(train)
                }
            }
            
        case .stateChanged(_):
            if train.state == .stopped {
                if try train.removeReservedBlocks() {
                    return .reservedBlocksChanged(train)
                }
            }
            
            if tsm.handleTrainState(train: train) {
                adjustSpeed(ofTrain: train, stateChanged: true)
                return .stateChanged(train)
            }

        case .restartTimerFired(_):
            train.startedRouteIndex = train.currentRouteIndex
            if try !train.shouldStopInBlock(ignoreReservedBlocks: true) && train.updateReservedBlocks() {
                return .reservedBlocksChanged(train)
            }

        case .reservedBlocksChanged(_), .reservedBlocksSettledLengthChanged(_):
            if tsm.handleTrainState(train: train) {
                adjustSpeed(ofTrain: train, stateChanged: true)
                return .stateChanged(train)
            } else {
                adjustSpeed(ofTrain: train, stateChanged: false)
            }
            
        case .speed(_):
            // Speed change can result in state change, for example when the speed reaches 0.
            if tsm.handleTrainState(train: train) {
                adjustSpeed(ofTrain: train, stateChanged: true)
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
    
    private func adjustSpeed(ofTrain train: TrainControlling, stateChanged: Bool) {
        if train.mode != .unmanaged {
            train.adjustSpeed(stateChanged: true)
        }
    }
}

extension StateMachine.TrainEvent {
    
    /// Returns true if this event belongs to the specified train.
    /// - Parameter train: the train
    /// - Returns: true if the event belongs to the train
    func belongs(toTrain train: TrainControlling) -> Bool {
        switch self {
        case .position(let te):
            return te.id == train.id
        case .speed(let te):
            return te.id == train.id
        case .modeChanged(let te):
            return te.id == train.id
        case .stateChanged(let te):
            return te.id == train.id
        case .restartTimerFired(let te):
            return te.id == train.id
        case .reservedBlocksChanged(let te):
            return te.id == train.id
        case .reservedBlocksSettledLengthChanged(let te):
            return te.id == train.id
        }
    }
}
