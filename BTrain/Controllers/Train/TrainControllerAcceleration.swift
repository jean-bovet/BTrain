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
import Combine

/// This class manages the acceleration/deceleration for a specific train.
///
/// When a speed change is requested, this class will progressively change the speed until it reaches the requested speed value.
/// The speed is incremented by a specified number of steps that is small enough to be executed by the Digital Controller.
final class TrainControllerAcceleration {
    
    /// The status of the speed change callback
    enum Status: CustomStringConvertible {
        /// The speed change has been cancelled
        case cancelled
        
        /// The speed change has completed
        case finished
        
        /// The speed change is in progress
        case working
        
        var description: String {
            switch self {
            case .cancelled:
                return "cancelled"
            case .finished:
                return "finished"
            case .working:
                return "working"
            }
        }
    }
        
    let train: Train
    let interface: CommandInterface
        
    /// The default step size when accelerating or decelerating.
    static let DefaultStepSize = 2
    
    /// The default step delay (100ms)
    static let DefaultStepDelay = 100
    
    /// The timer that handles the speed change given a specific acceleration/deceleration profile
    internal let speedChangeTimer: SpeedChangeTimer
    
    /// The timer that handles the delay to allow the locomotive to fully stop
    private let stopSettleDelayTimer = StopSettleDelayTimer()

    init(train: Train, interface: CommandInterface, speedChanged: CompletionBlock? = nil) {
        self.train = train
        self.interface = interface
        self.speedChangeTimer = SpeedChangeTimer(train: train)
        
        interface.register(forSpeedChange: { [weak self] address, decoder, value in
            DispatchQueue.main.async {
                if train.address.actualAddress(for: train.decoder) == address.actualAddress(for: decoder) {
                    // TODO: only do that if this is not an acknowledgement
                    train.speed.actualSteps = interface.speedSteps(for: value, decoder: train.decoder)
                    BTLogger.router.debug("\(train, privacy: .public): actual speed is \(train.speed.actualKph) kph (\(train.speed.actualSteps))")
                    speedChanged?()
                }
            }
        })
    }
    
    /// Request a change in the speed of a specific train, given an optional acceleration/deceleration profile.
    ///
    /// - Parameters:
    ///   - train: the train to change the speed
    ///   - acceleration: the acceleration/deceleration profile
    ///   - completion: a block called when the change is either completed or cancelled
    func changeSpeed(of train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock) {
        BTLogger.router.debug("\(train, privacy: .public): requesting speed of \(train.speed.requestedKph) kph (\(train.speed.requestedSteps)) from actual speed of \(train.speed.actualKph) kph (\(train.speed.actualSteps))")

        speedChangeTimer.cancel()
        stopSettleDelayTimer.cancel()

        let requestedKph = train.speed.requestedKph

        speedChangeTimer.schedule(from: train.speed.actualSteps, to: train.speed.requestedSteps,
                            acceleration: acceleration ?? train.speed.accelerationProfile) { [weak self] steps, status in
            self?.changeSpeedFired(steps: steps, status: status, train: train, requestedKph: requestedKph, completion: completion)
        }
    }

    private func changeSpeedFired(steps: SpeedStep, status: Status, train: Train, requestedKph: TrainSpeed.UnitKph, completion: @escaping CompletionCancelBlock) {
        let value = interface.speedValue(for: steps, decoder: train.decoder)
        let speedKph = train.speed.speedKph(for: steps)
        BTLogger.router.debug("\(train, privacy: .public): execute speed command for \(speedKph) kph (value=\(value), \(steps)), requested \(requestedKph) kph - \(status, privacy: .public)")
        
        interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: value)) { [weak self] in
            // TODO: happens in main thread or not?
            self?.speedCommandExecuted(steps: steps, status: status, train: train, requestedKph: requestedKph, completion: completion)
        }
    }
    
    private func speedCommandExecuted(steps: SpeedStep, status: Status, train: Train, requestedKph: TrainSpeed.UnitKph, completion: @escaping CompletionCancelBlock) {
        // Note: LayoutController+Listeners is the one listening for speed change acknowledgement from the Digital Controller and update the actual speed.
        // TODO: is that the best way or should we centralize that here?
        
        let value = interface.speedValue(for: steps, decoder: train.decoder)
        train.speed.actualSteps = interface.speedSteps(for: value, decoder: train.decoder)

        let speedKph = train.speed.speedKph(for: steps)
        BTLogger.router.debug("\(train, privacy: .public): done executing speed command for \(speedKph) kph (value=\(value), \(steps)), requested \(requestedKph) kph - \(status, privacy: .public)")
        if status == .finished || status == .cancelled {
            let finished = status == .finished
            if steps == .zero && finished {
                /// Settle only if the train stopped and the speed change hasn't been cancelled.
                /// Note: see comment in ``TrainControllerAcceleration/StopSettleDelayTimer``
                /// // TODO: wait for the acknowledgement from Digital Controller instead
                stopSettleDelayTimer.schedule(train: train, completed: finished, completion: completion)
            } else {
                completion(finished)
            }
        }
    }
        
}
