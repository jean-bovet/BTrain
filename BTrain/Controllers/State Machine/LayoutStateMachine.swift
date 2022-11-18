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

/// State machine for the entire layout. It uses internally two sub-state machine
/// to handle events specific to the layout and events specific to a train.
struct LayoutStateMachine {
    let lesm = LayoutEventStateMachine()
    let tesm = TrainEventStateMachine()

    func handle(layoutEvent: StateMachine.LayoutEvent? = nil, trainEvent: StateMachine.TrainEvent? = nil, trains: [TrainControlling], handledTrainEvents: inout [StateMachine.TrainEvent]?) throws {
        var trainEvents = [StateMachine.TrainEvent]()
        if let layoutEvent = layoutEvent {
            for train in trains {
                if let resultingTrainEvent = try lesm.handle(layoutEvent: layoutEvent, train: train) {
                    trainEvents.append(resultingTrainEvent)
                }
            }
        }

        if let trainEvent = trainEvent {
            trainEvents.append(trainEvent)
        }

        handledTrainEvents?.append(contentsOf: trainEvents)

        while trainEvents.count > 0 {
            let nextTrainEvent = trainEvents.removeFirst()
            for train in trains {
                if let resultingTrainEvent = try tesm.handle(trainEvent: nextTrainEvent, train: train) {
                    trainEvents.append(resultingTrainEvent)
                    handledTrainEvents?.append(resultingTrainEvent)
                }
            }
        }
    }
}
