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

struct TrainStateMachine {

    enum LayoutEvent {
        case feedback
        case speed
        case turnout
    }

    enum TrainEvent {
        case position(TrainModel)
        case speed(TrainModel)
        case scheduling(TrainModel)
        case restartTimerFired(TrainModel)
        case reservedBlocksChanged(TrainModel)
        case reservedBlocksSettledLengthChanged(TrainModel)
    }
        
    enum TrainState {
        case stopped
        case running
        case braking
        case stopping
    }

    func handle(layoutEvent: LayoutEvent?, trainEvent: TrainEvent?, trains: [TrainModel]) {
        var trainEvents = [TrainEvent]()
        if let layoutEvent = layoutEvent {
            for train in trains {
                if let trainEvent = handle(layoutEvent: layoutEvent, train: train) {
                    trainEvents.append(trainEvent)
                }
            }
        }
        
        if let trainEvent = trainEvent {
            trainEvents.append(trainEvent)
        }
        
        while trainEvents.count > 0 {
            let nextTrainEvent = trainEvents.removeFirst()
            for train in trains {
                if let resultingTrainEvent = handle(trainEvent: nextTrainEvent, train: train) {
                    trainEvents.append(resultingTrainEvent)
                }
            }
        }
    }
    
    /**
     Feedback Triggered > Update Train.Position
     Speed Changed > Update Train.Speed
     Turnout Changed > Update Settling of Train.Reserved.Blocks -> Emit Reserved.Blocks.Settled event
     */
    func handle(layoutEvent: LayoutEvent, train: TrainModel) -> TrainEvent? {
        switch layoutEvent {
        case .feedback:
            if train.updatePosition() {
                return handle(trainEvent: .position(train), train: train)
            }
        case .speed:
            if train.updateSpeed() {
                return handle(trainEvent: .speed(train), train: train)
            }
        case .turnout:
            if train.updateReservedBlocksLength() {
                return handle(trainEvent: .reservedBlocksSettledLengthChanged(train), train: train)
            }
        }
        return nil
    }
    
    /**
     Train.Position > Update Train.Occupied.Blocks + Train.Reserved.Blocks
     Train.Speed == 0 (rather State == .stopped) > Remove Train.Reserved.Blocks

     Train.Scheduling Changed to .managed > Update Train.Reserved.Blocks
     Train.RestartTimer Fired > Update Train.Reserved.Blocks

     Any.Other Train.Occupied.Blocks Updated > Update Train.Reserved.Blocks
     Any.Other Train.Reserved.Blocks Updated > Update Train.Reserved.Blocks

     Train.Reserved.Blocks Updated or Settled > Adjust Train.Speed
     */
    func handle(trainEvent: TrainEvent, train: TrainModel) -> TrainEvent? {
        switch trainEvent {
        case .position(let eventTrain):
            if eventTrain.id == train.id {
                if train.updateOccupiedAndReservedBlocks() {
                    handleTrainState(train: train)
                    return .reservedBlocksChanged(train)
                }
            }
            
        case .scheduling(let eventTrain):
            if eventTrain.id == train.id && train.isManagedSchedule {
                if train.updateReservedBlocks() {
                    handleTrainState(train: train)
                    return .reservedBlocksChanged(train)
                }
            }
            
        case .restartTimerFired(let eventTrain):
            if eventTrain.id == train.id {
                if train.updateReservedBlocks() {
                    handleTrainState(train: train)
                    return .reservedBlocksChanged(train)
                }
            }
            
        case .reservedBlocksChanged(let eventTrain):
            if eventTrain.id == train.id {
                train.adjustSpeed()
            } else {
                if train.updateReservedBlocks() {
                    return .reservedBlocksChanged(train)
                }
            }
            
        case .reservedBlocksSettledLengthChanged(let eventTrain):
            if eventTrain.id == train.id {
                train.adjustSpeed()
            }

        case .speed(_): // nothing to do
            break
        }
        
        return nil
    }

    private func handleTrainState(train: TrainModel) {
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
    }
    
    /**
     Running + Feedback.Brake + !(Train.Reserved.Blocks.Length) > Braking
     Running + Feedback.Brake + Stop.Managed > Braking
     Running + Feedback.Brake + Route.End > Braking
     Running + Feedback.Brake + Train.Block.Station > Braking
     */
    private func handleRunningState(train: TrainModel) {
        guard train.brakeFeedbackActivated else {
            return
        }
        
        if !train.reservedBlocksLengthEnoughToRun {
            train.state = .braking
        } else if train.stopManagedSchedule {
            train.state = .braking
        } else if train.atEndOfRoute {
            train.state = .braking
        } else if train.locatedInStationBlock {
            train.state = .braking
        }
    }
    
    /**
     Braking + Feedback.Stop + !(Train.Reserved.Blocks.Length) > Stopping
     Braking + Feedback.Stop + Stop.Managed > Stopping
     Braking + Feedback.Stop + Route.End > Stopping
     Braking + Feedback.Stop + Train.Block.Station > Stopping
     Braking + Train.Reserved.Blocks.Length + !Stop.Managed + !Train.Block.Station + !Route.End > Running
     */
    private func handleBrakingState(train: TrainModel) {
        if train.stopFeedbackActivated {
            if !train.reservedBlocksLengthEnoughToRun {
                train.state = .stopping
            } else if train.stopManagedSchedule {
                train.state = .stopping
            } else if train.atEndOfRoute {
                train.state = .stopping
            } else if train.locatedInStationBlock {
                train.state = .stopping
            }
        } else if train.reservedBlocksLengthEnoughToRun &&
                    !train.stopManagedSchedule &&
                    !train.locatedInStationBlock &&
                    !train.atEndOfRoute {
            train.state = .running
        }
    }

    /**
     Stopping + Speed Changed (=0) > Stopped
     */
    private func handleStoppingState(train: TrainModel) {
        if train.speed == 0 {
            train.state = .stopped
        }
    }
    
    /**
     Stopped + Train.Reserved.Blocks.Length + !Stop.Managed > Running
     */
    private func handleStoppedState(train: TrainModel) {
        if train.reservedBlocksLengthEnoughToRun && !train.stopManagedSchedule {
            train.state = .running
        }
    }
}
