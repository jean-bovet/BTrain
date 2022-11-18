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
        case speed(TrainControlling, SpeedKph)
        case turnout(Turnout)
        case direction(TrainControlling)
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

extension LayoutControllerEvent {
    func layoutEvent(layoutController: LayoutController) -> StateMachine.LayoutEvent? {
        switch self {
        case let .feedbackTriggered(feedback):
            return .feedback(feedback)

        case let .turnoutChanged(turnout):
            return .turnout(turnout)

        case let .directionChanged(train):
            if let tc = layoutController.trainController(forTrain: train) {
                return .direction(tc)
            } else {
                return nil
            }

        case let .speedChanged(train, actualKph):
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
        case let .schedulingChanged(train):
            if let tc = layoutController.trainController(forTrain: train) {
                return .modeChanged(tc)
            }
        case let .restartTimerExpired(train: train):
            if let tc = layoutController.trainController(forTrain: train) {
                return .restartTimerFired(tc)
            }
        case let .trainPositionChanged(train):
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
        case .position:
            return "position"
        case .speed:
            return "speed"
        case .modeChanged:
            return "scheduling"
        case .stateChanged:
            return "stateChanged"
        case .restartTimerFired:
            return "restartTimerFired"
        case .reservedBlocksChanged:
            return "reservedBlocksChanged"
        case .reservedBlocksSettledLengthChanged:
            return "reservedBlocksSettledLengthChanged"
        }
    }
}
