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
    
    /// The scheduling of the train (see ``StateMachine/TrainScheduling``
    var mode: StateMachine.TrainMode { get }

    /// The state of the train (see ``StateMachine/TrainState``)
    var state: StateMachine.TrainState { get set }
    
    /// The speed of the train
    var speed: TrainSpeed.UnitKph { get set }
    
    /// Returns true if the brake feedback is detected
    var brakeFeedbackActivated: Bool { get }
        
    /// Returns true if the stop feedback is detected
    var stopFeedbackActivated: Bool { get }
    
    /// The start index of the route where the train started.
    ///
    /// It is not necessarily the beginning of the route (index 0); for example a train that stopped in a station
    /// in the middle of route will have this value be > 0 when it starts again from the station.
    var startedRouteIndex: Int { get set }
        
    /// The current index of the route where the train is located
    var currentRouteIndex: Int { get }
        
    /// The end index of the route
    var endRouteIndex: Int { get }
    
    /// Returns true if the train is located in a station
    var atStation: Bool { get }
        
    func reservedBlocksLengthEnough(forSpeed speed: TrainSpeed.UnitKph) -> Bool

    func updatePosition(with feedback: Feedback) -> Bool
        
    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool
    
    func updateOccupiedAndReservedBlocks() -> Bool
    
    func updateReservedBlocks() -> Bool
    
    func removeReservedBlocks() -> Bool
    
    /// Adjusts the speed of the train given the current context. This method is called when the reserved blocks
    /// changed or the settling length of the reserved block changed.
    func adjustSpeed()
}
