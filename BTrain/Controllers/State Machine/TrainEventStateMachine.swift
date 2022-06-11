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

struct TrainEventStateMachine {
        
    let tsm = TrainStateMachine()

    /**
     Train.Position > Update Train.Occupied.Blocks + Train.Reserved.Blocks
     Train.Speed == 0 (rather State == .stopped) > Remove Train.Reserved.Blocks

     Train.Scheduling Changed to .managed > Update Train.Reserved.Blocks
     Train.RestartTimer Fired > Update Train.Reserved.Blocks

     Any.Other Train.Occupied.Blocks Updated > Update Train.Reserved.Blocks
     Any.Other Train.Reserved.Blocks Updated > Update Train.Reserved.Blocks

     Train.Reserved.Blocks Updated or Settled > Adjust Train.Speed
     */
    func handle(trainEvent: StateMachine.TrainEvent, train: TrainControlling) -> [StateMachine.TrainEvent] {
        var resultingEvents = [StateMachine.TrainEvent]()
        switch trainEvent {
        case .position(let eventTrain):
            if eventTrain.id == train.id {
                if train.updateOccupiedAndReservedBlocks() {
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .scheduling(let eventTrain):
            if eventTrain.id == train.id && train.scheduling == .managed {
                if train.updateReservedBlocks() {
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .stateChanged(let eventTrain):
            if eventTrain.id == train.id {
                if train.state == .stopped {
                    train.removeReservedBlocks()
                }
                if tsm.handleTrainState(train: train) {
                    resultingEvents.append(.stateChanged(train))
                }
            }

        case .restartTimerFired(let eventTrain):
            if eventTrain.id == train.id {
                train.resetStartRouteIndex()
                if !train.shouldStop && train.updateReservedBlocks() {
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .reservedBlocksChanged(let eventTrain):
            if eventTrain.id == train.id {
                if tsm.handleTrainState(train: train) {
                    resultingEvents.append(.stateChanged(train))
                }
                train.adjustSpeed()
            } else {
                if train.updateReservedBlocks() {
                    resultingEvents.append(.reservedBlocksChanged(train))
                }
            }
            
        case .reservedBlocksSettledLengthChanged(let eventTrain):
            if eventTrain.id == train.id {
                train.adjustSpeed()
            }

        case .speed(let eventTrain):
            // Speed change can result in state change, for example when the speed reaches 0.
            if eventTrain.id == train.id {
                if tsm.handleTrainState(train: train) {
                    resultingEvents.append(.stateChanged(train))
                }
            }
        }
        
        return resultingEvents
    }

}
