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

import XCTest
@testable import BTrain

final class MockTrainController: TrainControlling {

    var id: String = UUID().uuidString
    
    var state: TrainStateMachine.TrainState = .stopped
    
    var speed: TrainSpeed.UnitKph = 0
        
    var isManagedSchedule: Bool = true
    
    var stopManagedSchedule: Bool = false

    var reservedBlocksLengthEnoughToRun: Bool = false
    
    var brakeFeedbackActivated: Bool = false
    
    var stopFeedbackActivated: Bool = false
    
    var atEndOfRoute: Bool = false
    
    var locatedInStationBlock: Bool = false
    
    typealias CallbackBlock = () -> Bool

    var onUpdatePosition: ((Feedback) -> Bool)?
    var updatePositionInvocationCount = 0

    func updatePosition(with feedback: Feedback) -> Bool {
        updatePositionInvocationCount += 1
        return onUpdatePosition?(feedback) ?? false
    }
    
    var onUpdateSpeed: CallbackBlock?

    func updateSpeed() -> Bool {
        onUpdateSpeed?() ?? false
    }
    
    var onUpdateReservedBlocksSettledLength: ((Turnout) -> Bool)?

    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool {
        onUpdateReservedBlocksSettledLength?(turnout) ?? false
    }

    var onUpdateOccupiedAndReservedBlocks: CallbackBlock?

    func updateOccupiedAndReservedBlocks() -> Bool {
        onUpdateOccupiedAndReservedBlocks?() ?? false
    }
        
    var onUpdateReservedBlocks: CallbackBlock?
    var updateReservedBlocksInvocationCount = 0
    
    func updateReservedBlocks() -> Bool {
        updateReservedBlocksInvocationCount += 1
        return onUpdateReservedBlocks?() ?? false
    }
    
    var adjustSpeedCount = 0
    
    func adjustSpeed() {
        adjustSpeedCount += 1
        
        switch state {
        case .running:
            speed = LayoutFactory.DefaultMaximumSpeed
        case .braking:
            speed = LayoutFactory.DefaultBrakingSpeed
        case .stopping:
            speed = LayoutFactory.DefaultBrakingSpeed
        case .stopped:
            speed = 0
        }
    }
    
}
