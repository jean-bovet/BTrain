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
        case feedback(Feedback)
        case speed
        case turnout(Turnout)
    }

    enum TrainEvent {
        case position(TrainControlling)
        case speed(TrainControlling)
        case scheduling(TrainControlling)
        case stateChanged(TrainControlling)
        case restartTimerFired(TrainControlling)
        case reservedBlocksChanged(TrainControlling)
        case reservedBlocksSettledLengthChanged(TrainControlling)        
    }
        
    enum TrainState {
        case stopped
        case running
        case braking
        case stopping
    }

    enum TrainStopSignal {
        case none
        case atEndOfRoute
        case inStation
        case stopManaged
    }
    
    func handle(layoutEvent: LayoutEvent?, trainEvent: TrainEvent?, trains: [TrainControlling]) {
        var events: [TrainEvent]? = nil
        handle(layoutEvent: layoutEvent, trainEvent: trainEvent, trains: trains, handledTrainEvents: &events)
    }
    
    func handle(layoutEvent: LayoutEvent?, trainEvent: TrainEvent?, trains: [TrainControlling], handledTrainEvents: inout [TrainEvent]?) {
        var trainEvents = [TrainEvent]()
        if let layoutEvent = layoutEvent {
            for train in trains {
                let resultingTrainEvents = handle(layoutEvent: layoutEvent, train: train)
                trainEvents.append(contentsOf: resultingTrainEvents)
            }
        }
        
        if let trainEvent = trainEvent {
            trainEvents.append(trainEvent)
        }
        
        handledTrainEvents?.append(contentsOf: trainEvents)
        
        while trainEvents.count > 0 {
            let nextTrainEvent = trainEvents.removeFirst()
            for train in trains {
                let resultingTrainEvents = handle(trainEvent: nextTrainEvent, train: train)
                trainEvents.append(contentsOf: resultingTrainEvents)
                handledTrainEvents?.append(contentsOf: resultingTrainEvents)
            }
        }
    }
    
    /**
     Feedback Triggered > Update Train.Position
     Speed Changed > Update Train.Speed
     Turnout Changed > Update Settling of Train.Reserved.Blocks -> Emit Reserved.Blocks.Settled event
     */
    func handle(layoutEvent: LayoutEvent, train: TrainControlling) -> [TrainEvent] {
        switch layoutEvent {
        case .feedback(let feedback):
            if train.updatePosition(with: feedback) {
                return handle(trainEvent: .position(train), train: train)
            }
        case .speed:
            if train.updateSpeed() {
                return handle(trainEvent: .speed(train), train: train)
            }
        case .turnout(let turnout):
            if train.updateReservedBlocksSettledLength(with: turnout) {
                return handle(trainEvent: .reservedBlocksSettledLengthChanged(train), train: train)
            }
        }
        return []
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
    func handle(trainEvent: TrainEvent, train: TrainControlling) -> [TrainEvent] {
        var resultingEvents = [TrainEvent]()
        switch trainEvent {
        case .position(let eventTrain):
            if eventTrain.id == train.id {
                if train.updateOccupiedAndReservedBlocks() {
                    if handleTrainState(train: train) {
                        resultingEvents.append(.stateChanged(train))
                    }
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .scheduling(let eventTrain):
            if eventTrain.id == train.id && train.isManagedSchedule {
                if train.updateReservedBlocks() {
                    if handleTrainState(train: train) {
                        resultingEvents.append(.stateChanged(train))
                    }
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .stateChanged(let eventTrain):
            if eventTrain.id == train.id {
                if handleTrainState(train: train) {
                    resultingEvents.append(.stateChanged(train))
                }
            }

        case .restartTimerFired(let eventTrain):
            if eventTrain.id == train.id {
                if train.updateReservedBlocks() {
                    if handleTrainState(train: train) {
                        resultingEvents.append(.stateChanged(train))
                    }
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .reservedBlocksChanged(let eventTrain):
            if eventTrain.id == train.id {
                if train.state != .stopped {
                    train.adjustSpeed()
                }
            } else {
                if train.updateReservedBlocks() {
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .reservedBlocksSettledLengthChanged(let eventTrain):
            if eventTrain.id == train.id {
                if train.state != .stopped {
                    train.adjustSpeed()
                }
            }

        case .speed(let eventTrain):
            // Speed change can result in state change, for example when the speed reaches 0.
            if eventTrain.id == train.id {
                if handleTrainState(train: train) {
                    resultingEvents.append(.stateChanged(train))
                }
            }
        }
        
        return resultingEvents
    }

    private func handleTrainState(train: TrainControlling) -> Bool {
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
        } else if train.brakeFeedbackActivated {
            switch train.stopSignal {
            case .stopManaged:
                train.state = .braking
            case .atEndOfRoute:
                train.state = .braking
            case .inStation:
                train.state = .braking
            case .none:
                break
            }
        } else if train.stopFeedbackActivated {
            switch train.stopSignal {
            case .stopManaged:
                train.state = .stopping
            case .atEndOfRoute:
                train.state = .stopping
            case .inStation:
                train.state = .stopping
            case .none:
                break
            }
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
            switch train.stopSignal {
            case .stopManaged:
                if train.stopFeedbackActivated {
                    train.state = .stopping
                }
            case .atEndOfRoute:
                if train.stopFeedbackActivated {
                    train.state = .stopping
                }
            case .inStation:
                if train.stopFeedbackActivated {
                    train.state = .stopping
                }
            case .none:
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
        if train.reservedBlocksLengthEnough(forSpeed: LayoutFactory.DefaultMaximumSpeed) && train.stopSignal == .none {
            train.state = .running
        }
    }
}
