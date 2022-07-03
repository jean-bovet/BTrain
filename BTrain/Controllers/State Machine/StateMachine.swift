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

struct StateMachine {
    
    enum LayoutEvent {
        case feedback(Feedback)
        case speed(TrainControlling, TrainSpeed.UnitKph)
        case turnout(Turnout)
    }
    
    enum TrainEvent {
        case position(TrainControlling)
        case speed(TrainControlling)
        case modeChanged(TrainControlling)
        case stateChanged(TrainControlling)
        case restartTimerFired(TrainControlling)
        case reservedBlocksChanged(TrainControlling)
        case reservedBlocksSettledLengthChanged(TrainControlling)
    }
     
    typealias TrainState = Train.State

    typealias TrainMode = Train.Schedule

}

extension TrainEvent {
    
    func layoutEvent(layoutController: LayoutController) -> StateMachine.LayoutEvent? {
        switch self {
        case .feedbackTriggered(let feedback):
            return .feedback(feedback)
        case .turnoutChanged(let turnout):
            return .turnout(turnout)
        case .directionChanged:
            return nil // TODO
        case .speedChanged(let train, let actualKph):
            if let tc = layoutController.trainController(forTrain: train) {
                return .speed(tc, actualKph)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    func trainEvent(layoutController: LayoutController) -> StateMachine.TrainEvent? {
        switch self {
        case .schedulingChanged(let train):
            if let tc = layoutController.trainController(forTrain: train) {
                return .modeChanged(tc)
            }
        case .restartTimerExpired(train: let train):
            if let tc = layoutController.trainController(forTrain: train) {
                return .restartTimerFired(tc)
            }
        case .movedInsideBlock(let train), .movedToNextBlock(let train):
            if let tc = layoutController.trainController(forTrain: train) {
                return .position(tc)
            }
        default: return nil
        }
        return nil
    }
}

extension StateMachine.TrainEvent: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .position(_):
            return "position"
        case .speed(_):
            return "speed"
        case .modeChanged(_):
            return "scheduling"
        case .stateChanged(_):
            return "stateChanged"
        case .restartTimerFired(_):
            return "restartTimerFired"
        case .reservedBlocksChanged(_):
            return "reservedBlocksChanged"
        case .reservedBlocksSettledLengthChanged(_):
            return "reservedBlocksSettledLengthChanged"
        }
    }

}
