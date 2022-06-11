//
//  TrainInternalStateMachine.swift
//  BTrain
//
//  Created by Jean Bovet on 6/11/22.
//

import Foundation

struct TrainInternalStateMachine {
    
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
            train.removeReservedBlocks()
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
