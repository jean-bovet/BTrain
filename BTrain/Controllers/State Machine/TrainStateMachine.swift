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

// TODO: unit tests
struct TrainStateMachine {
    
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
        return originalState != train.state
    }
    
    /**
     Running + !(Train.Reserved.Blocks.Length) > Braking
     Running + Feedback.Brake + Stop.Managed > Braking
     Running + Feedback.Brake + Route.End > Braking
     Running + Feedback.Brake + Train.Block.Station > Braking
     */
    private func handleRunningState(train: TrainControlling) {
        if !train.reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultMaximumSpeed) {
            train.state = .braking
        } else if train.brakeFeedbackActivated && train.shouldStop {
            train.state = .braking
        } else if train.stopFeedbackActivated && train.shouldStop {
            train.state = .stopping
        }
    }
    
    /**
     Braking + Feedback.Stop + !(Train.Reserved.Blocks.Length) > Stopping
     Braking + Feedback.Stop + Stop.Managed > Stopping
     Braking + Feedback.Stop + Route.End > Stopping
     Braking + Feedback.Stop + Train.Block.Station > Stopping
     Braking + Train.Reserved.Blocks.Length + !Stop.Managed + !Train.Block.Station + !Route.End > Running
     */
    private func handleBrakingState(train: TrainControlling) {
        if !train.reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultBrakingSpeed) {
            train.state = .stopping
        } else {
            if train.shouldStop {
                if train.stopFeedbackActivated {
                    train.state = .stopping
                }
            } else {
                if train.reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultMaximumSpeed) {
                    train.state = .running
                }
            }
        }
    }

    /**
     Stopping + Speed Changed (=0) > Stopped
     */
    private func handleStoppingState(train: TrainControlling) {
        if train.speed == 0 {
            train.state = .stopped
        }
    }
    
    /**
     Stopped + Train.Reserved.Blocks.Length + !Stop.Managed > Running
     */
    private func handleStoppedState(train: TrainControlling) {
        if !train.shouldStop && train.reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultMaximumSpeed) {
            train.state = .running
        }
    }
    
}

extension TrainControlling {
    
    var shouldStop: Bool {
        // User requested to stop managing the train?
        if scheduling == .stopManaged {
            return true
        }
        
        // User requested to finish managing the train when it reaches the end of the route?
        if scheduling == .finishManaged && currentRouteIndex >= endRouteIndex {
            return true
        }

        // In a station but not in the first step of the route?
        if atStation && currentRouteIndex > startedRouteIndex {
            return true
        }
        
        // At the end of the route?
        if currentRouteIndex >= endRouteIndex {
            return true
        }
        
        return false
    }

}
