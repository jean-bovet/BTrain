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
    
    var mode: StateMachine.TrainMode = .unmanaged
    
    var state: StateMachine.TrainState = .stopped
    
    var route: Route
    
    var speed: SpeedKph = 0
            
    var brakeFeedbackActivated: Bool = false
    
    var stopFeedbackActivated: Bool = false
            
    var hasReservedBlocks = false
    
    var startedRouteIndex: Int = 0
    var currentRouteIndex: Int = 0
    var endRouteIndex: Int = 10
        
    var atEndOfRoute: Bool {
        currentRouteIndex >= endRouteIndex
    }
    
    var atStationOrDestination: Bool = false
    
    var reservedBlocksSettling: Bool = false
    
    init(route: Route) {
        self.route = route
    }
    
    func moveToEndOfRoute() {
        currentRouteIndex = 10
        endRouteIndex = 10
    }
    
    typealias OnReservedBlocksLengthEnough = (SpeedKph) -> Bool
    var onReservedBlocksLengthEnough: OnReservedBlocksLengthEnough?

    func reservedBlocksLengthEnough(forSpeed speed: SpeedKph) -> Bool {
        guard let block = onReservedBlocksLengthEnough else {
            XCTFail("No callback setup to assert this method call")
            return false
        }

        return block(speed)
    }

    typealias CallbackBlock = () -> Bool

    var onUpdatePosition: ((Feedback) -> Bool)?
    var updatePositionInvocationCount = 0

    func updatePosition(with feedback: Feedback) -> Bool {
        updatePositionInvocationCount += 1
        guard let block = onUpdatePosition else {
            XCTFail("No callback setup to assert this method call")
            return false
        }

        return block(feedback)
    }
        
    var onUpdateReservedBlocksSettledLength: ((Turnout) -> Bool)?

    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool {
        guard let block = onUpdateReservedBlocksSettledLength else {
            XCTFail("No callback setup to assert this method call")
            return false
        }

        return block(turnout)
    }

    var onUpdateOccupiedAndReservedBlocks: CallbackBlock?

    func updateOccupiedAndReservedBlocks() -> Bool {
        guard let block = onUpdateOccupiedAndReservedBlocks else {
            XCTFail("No callback setup to assert this method call")
            return false
        }
        let result = block()
        if result {
            hasReservedBlocks = true
        }
        return result
    }
        
    var onUpdateReservedBlocks: CallbackBlock?
    var updateReservedBlocksInvocationCount = 0
    
    func updateReservedBlocks() -> Bool {
        updateReservedBlocksInvocationCount += 1
        guard let block = onUpdateReservedBlocks else {
            XCTFail("No callback setup to assert this method call")
            return false
        }

        let result = block()
        if result {
            hasReservedBlocks = true
        }
        return result
    }
    
    func removeReservedBlocks() -> Bool {
        if hasReservedBlocks {
            hasReservedBlocks = false
            return true
        } else {
            return false
        }
    }
    
    var adjustSpeedCount = 0
    
    func adjustSpeed(stateChanged: Bool) {
        adjustSpeedCount += 1
        
        if stateChanged {
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
        } else if state == .running {
            speed = LayoutFactory.DefaultMaximumSpeed
        }
    }
    
    func stopImmediately() {
        
    }
    
    func reschedule() {
        // no-op
    }
}
