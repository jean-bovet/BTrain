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

/// State machine that handles only the state transition of the train
struct TrainStateStateMachine {
    
    func handleTrainState(train: TrainControlling) -> Bool {
        let originalState = train.state
        switch train.state {
        case .running:
            handleRunningState(train: train)
        case .braking:
            handleBrakingState(train: train)
        case .stopping:
            handleStoppingState(train: train)
        case .stopped:
            handleStoppedState(train: train)
        }
        let stateChanged = originalState != train.state
        if train.state == .stopped && (stateChanged || train.mode == .stopManaged) {
            trainDidStop(train: train)
        }
        return stateChanged
    }
    
    private func handleRunningState(train: TrainControlling) {
        if train.mode == .unmanaged {
            if train.speed == 0 {
                train.state = .stopped
            }
        } else {
            if train.brakeFeedbackActivated && train.shouldStopInBlock {
                train.state = .braking
            } else if train.stopFeedbackActivated && train.shouldStopInBlock {
                train.state = .stopping
            } else if train.shouldStopInBlockBecauseNotEnoughReservedBlocksLength {
                train.state = .stopping
            }
        }
    }
    
    private func handleBrakingState(train: TrainControlling) {
        if train.shouldStopInBlock {
            if train.stopFeedbackActivated {
                train.state = .stopping
            }
        } else {
            train.state = .running
        }
    }

    private func handleStoppingState(train: TrainControlling) {
        if train.shouldStopInBlock {
            if train.speed == 0 {
                train.state = .stopped
            }
        } else {
            train.state = .running
        }
    }
    
    private func handleStoppedState(train: TrainControlling) {
        if train.mode == .managed || train.mode == .finishManaged {
            if !train.shouldStopInBlock {
                train.state = .running
            }
        } else if train.mode == .unmanaged {
            if train.speed > 0 {
                train.state = .running
            }
        }
    }
    
}

extension TrainStateStateMachine {
    
    /// When the train stops, we need to take care of the status of the train
    /// because depending on the route mode (fixed, automatic or automaticOnce),
    /// we need to re-schedule the train, stop it or simply do nothing.
    /// - Parameter train: the train to handle
    func trainDidStop(train: TrainControlling) {
        guard train.mode != .unmanaged else {
            return
        }
        
        let reachedStationOrDestination = train.atStationOrDestination

        switch train.route.mode {
        case .fixed:
            if (reachedStationOrDestination && train.mode == .finishManaged)
                || train.mode == .stopManaged
                || train.atEndOfRoute {
                train.mode = .unmanaged
            } else if reachedStationOrDestination {
                train.reschedule()
            }

        case .automatic:
            if (reachedStationOrDestination && train.mode == .finishManaged)
                || train.mode == .stopManaged {
                train.mode = .unmanaged
            } else if reachedStationOrDestination {
                train.reschedule()
            }

        case .automaticOnce(destination: _):
            if reachedStationOrDestination || train.mode == .stopManaged {
                train.mode = .unmanaged
            }
        }
    }
    
}
