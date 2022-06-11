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

/// Protocol defining the states and operations that the state machine is expecting from a train.
///
/// It is a convenient way to abstract out the logic of the train from its implementation and makes it easier
/// to read the state machine flow and interaction with the train.
protocol TrainControlling: AnyObject {
    
    /// Unique ID of the train
    var id: String { get }

    var scheduling: TrainStateMachine.TrainScheduling { get }

    /// The state of the train (see ``TrainStateMachine/TrainState``)
    var state: TrainStateMachine.TrainState { get set }
    
    /// The speed of the train
    var speed: TrainSpeed.UnitKph { get set }
        
    var brakeFeedbackActivated: Bool { get }
    var stopFeedbackActivated: Bool { get }
    
    var startedRouteIndex: Int { get }
    var currentRouteIndex: Int { get }
    var endRouteIndex: Int { get }
    
    var atStation: Bool { get }
    
    func resetStartRouteIndex()
    
    func reservedBlocksLengthEnough(forSpeed speed: TrainSpeed.UnitKph) -> Bool

    func updatePosition(with feedback: Feedback) -> Bool
        
    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool
    
    func updateOccupiedAndReservedBlocks() -> Bool
    
    func updateReservedBlocks() -> Bool
    
    func removeReservedBlocks()
    
    /// Adjusts the speed of the train given the current context. This method is called when the reserved blocks
    /// changed or the settling length of the reserved block changed.
    func adjustSpeed()
}
