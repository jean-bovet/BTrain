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
    var mode: StateMachine.TrainMode { get set }

    /// The state of the train (see ``StateMachine/TrainState``)
    var state: StateMachine.TrainState { get set }
    
    /// The route associated with the train
    var route: Route { get }
    
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
        
    /// Returns true if the train is located at the end of the route
    var atEndOfRoute: Bool { get }
    
    /// Returns true if the train is located in a station or at the destination block as specified by the route
    var atStationOrDestination: Bool { get }
    
    /// Returns true if the reserved blocks are still settling
    var reservedBlocksSettling: Bool { get }
    
    /// Returns true if the length of reserved blocks is long enough to allow the train
    /// to move at the specified speed. The lenght must only includes settled turnouts,
    /// because un-settled turnouts are not yet ready to be used by the train.
    /// - Parameter speed: the speed to evaluate
    /// - Returns: true if the length of reserved blocks is long enoug, false otherwise
    func reservedBlocksLengthEnough(forSpeed speed: TrainSpeed.UnitKph) -> Bool
    
    /// Updates the position of the train given the specified feedback activation
    /// - Parameter feedback: The feedback that is activated
    /// - Returns: true if the position of the train was updated, false otherwse
    func updatePosition(with feedback: Feedback) throws -> Bool
    
    /// Updates the settled length of the reserved blocks
    /// - Parameter turnout: the turnout that has settled
    /// - Returns: true if the settled length has changed
    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool
    
    /// Updates the occupied and reserved blocks of the train.
    ///
    /// An occupied block is one that contains a portion (or all) of the train.
    /// A reserved block is one that has been reserved for a particular train but that does not contain it yet.
    /// - Returns: true if the occupied and reserved blocks have changed
    func updateOccupiedAndReservedBlocks() throws -> Bool
    
    /// Updates the reserved blocks of the train
    /// - Returns: true if the reserved blocks have changed
    func updateReservedBlocks() throws -> Bool
    
    /// Removes the reserved blocks of the train
    /// - Returns: true if the reserved blocks have changed
    func removeReservedBlocks() throws -> Bool
    
    /// Adjusts the speed of the train given the current context.
    ///
    /// This method is called when the reserved blocks changed or the settling length of the reserved block changed.
    /// - Parameter stateChanged: true if this method is called when the state of the train changed
    func adjustSpeed(stateChanged: Bool)
    
    /// Schedule a timer that will restart the train after a specific waiting period
    func reschedule()
}
