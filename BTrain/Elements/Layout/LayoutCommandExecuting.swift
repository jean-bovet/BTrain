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

typealias CompletionBlock = (() -> Void)
typealias CompletionCancelBlock = ((_ completed: Bool) -> Void)

/// Protocol defining the commands that a layout can execute.
protocol LayoutCommandExecuting: AnyObject {
    
    /// Send a turnout state command
    ///
    /// - Parameters:
    ///   - turnout: the turnout whose state need to be sent to the Digital Controller
    ///   - completion: completion block called when the command has been sent
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock)
    
    /// Send a train direction command
    ///
    /// - Parameters:
    ///   - train: the train to change the direction
    ///   - forward: true for forward direction, false for backward direction
    ///   - completion: completion block called when the command has been sent
    func sendTrainDirection(train: Train, forward: Bool, completion: @escaping CompletionBlock)
        
    /// Send a train speed command
    ///
    /// - Parameters:
    ///   - train: the train to change the speed
    ///   - acceleration: an optional acceleration profile
    ///   - completion: completion block called when the speed change is either completed or cancelled. The speed change can be cancelled if another speed change is requested
    ///   when one is already in progress.
    func sendTrainSpeed(train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock)

}

final class DefaultCommandExecutor: LayoutCommandExecuting {
    func sendTurnoutState(turnout: Turnout, completion: @escaping CompletionBlock) {
        turnout.actualState = turnout.requestedState
        completion()
    }
    
    func sendTrainDirection(train: Train, forward: Bool, completion: @escaping CompletionBlock) {
        completion()
    }
    
    func sendTrainSpeed(train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock) {
        train.speed.actualSteps = train.speed.requestedSteps
        completion(true)
    }
    
}
