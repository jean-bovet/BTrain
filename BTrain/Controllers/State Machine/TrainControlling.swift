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

protocol TrainControlling: AnyObject {
    
    /// Unique ID of the train
    var id: String { get }
    
    /// The state of the train (see ``TrainStateMachine/TrainState``)
    var state: TrainStateMachine.TrainState { get set }
    
    var speed: TrainSpeed.UnitKph { get }
    
    var isManagedSchedule: Bool { get }
    
    var brakeFeedbackActivated: Bool { get }
    var stopFeedbackActivated: Bool { get }
    
    /// A stop signal is a signal that indicates that the train should stop
    /// as soon as possible. For example, when reaching a station
    /// or when arriving at the end of a route.
    var stopSignal: TrainStateMachine.TrainStopSignal { get }
    
    func reservedBlocksLengthEnough(forSpeed speed: TrainSpeed.UnitKph) -> Bool

    func updatePosition(with feedback: Feedback) -> Bool
    
    func updateSpeed() -> Bool
    
    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool
    
    func updateOccupiedAndReservedBlocks() -> Bool
    
    func updateReservedBlocks() -> Bool
    
    func adjustSpeed()
}
