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
final class TrainSpeedManager {
    
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
    internal var speedChangeTimer: Timer?
    
    /// The timer that handles the delay to allow the locomotive to fully stop
    private let stopSettleDelayTimer = StopSettleDelayTimer()

    internal var lastRequestedKph: TrainSpeed.UnitKph?
    
    final class SpeedCommand {
        let requestUUID: Int
        let requestedKph: TrainSpeed.UnitKph
        let requestedSteps: SpeedStep
        
        var steps: [SpeedStep]
        var completionBlocks: [CompletionCancelBlock]

        var status: Status = .working
        var waitingForCompletionFromInterface = false

        init(requestUUID: Int, requestedKph: TrainSpeed.UnitKph, requestedSteps: SpeedStep, steps: [SpeedStep], completion: @escaping CompletionCancelBlock) {
            self.requestUUID = requestUUID
            self.requestedKph = requestedKph
            self.requestedSteps = requestedSteps
            self.steps = steps
            self.completionBlocks = [completion]
        }
    }
    
    var scheduledCommands = [SpeedCommand]()
    var processingCommand: SpeedCommand?
    
    // The delay between step increments, recommended to be about 100ms.
    var stepDelay: TimeInterval {
        if let delay = train.speed.accelerationStepDelay {
            return Double(delay) / 1000
        } else {
            return Double(TrainSpeedManager.DefaultStepDelay) / 1000
        }
    }
    
    init(train: Train, interface: CommandInterface, speedChanged: CompletionBlock? = nil) {
        self.train = train
        self.interface = interface
        
        interface.register(forSpeedChange: { address, decoder, value in
            if train.address.actualAddress(for: train.decoder) == address.actualAddress(for: decoder) {
                // Note: the `speedCommandExecuted` function below is also updating the actual steps
                // when a speed command completion happens. This is fine because for each speed change,
                // we need to call both the completion block and the change callback here.
                train.speed.actualSteps = interface.speedSteps(for: value, decoder: train.decoder)
                BTLogger.speed.debug("\(train, privacy: .public): actual speed is \(train.speed.actualKph) kph (\(train.speed.actualSteps))")
                speedChanged?()
            }
        })
    }
    
    /// Global UUID used to uniquely identify each speed change request in order to ease the debugging
    static var globalRequestUUID = 0
    
    /// Request a change in the speed of a specific train, given an optional acceleration/deceleration profile.
    ///
    /// - Parameters:
    ///   - train: the train to change the speed
    ///   - acceleration: the acceleration/deceleration profile
    ///   - completion: a block called when the change is either completed or cancelled
    func changeSpeed(acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock) {
        TrainSpeedManager.globalRequestUUID += 1
        let requestUUID = TrainSpeedManager.globalRequestUUID
                
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(requestUUID)} scheduling request for speed of \(self.train.speed.requestedKph) kph (\(self.train.speed.requestedSteps)) from actual speed of \(self.train.speed.actualKph) kph (\(self.train.speed.actualSteps))")
        
        if let processingCommand = processingCommand {
            if processingCommand.requestedKph == train.speed.requestedKph {
                BTLogger.speed.debug("\(self.train, privacy: .public): {\(requestUUID)} attaching to previous request {\(processingCommand.requestUUID)} because the requested speed of \(self.train.speed.requestedKph) is the same")
                processingCommand.completionBlocks.append(completion)
            } else {
                BTLogger.speed.debug("\(self.train, privacy: .public): {\(requestUUID)} cancelling previous speed request {\(processingCommand.requestUUID)}")
                scheduleSpeedChangeCommand(acceleration: acceleration, completion: completion, requestUUID: requestUUID)
                processingCommand.status = .cancelled
                speedChangeTimer?.invalidate()
                if !processingCommand.waitingForCompletionFromInterface {
                    processSpeedCommand(command: processingCommand)
                }
            }
            return
        }
        
        scheduleSpeedChangeCommand(acceleration: acceleration, completion: completion, requestUUID: requestUUID)
        executePendingSpeedChangeCommand()
    }

    private func scheduleSpeedChangeCommand(acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionCancelBlock, requestUUID: Int) {
        let steps = speedCommands(from: train.speed.actualSteps, to: train.speed.requestedSteps, acceleration: acceleration ?? train.speed.accelerationProfile)
        scheduledCommands.append(SpeedCommand(requestUUID: requestUUID, requestedKph: train.speed.requestedKph, requestedSteps: train.speed.requestedSteps, steps: steps, completion: completion))
    }
    
    private func executePendingSpeedChangeCommand() {
        guard let command = scheduledCommands.first else {
            return
        }
        
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} requesting speed of \(command.requestedKph) kph (\(command.requestedSteps)) from actual speed of \(self.train.speed.actualKph) kph (\(self.train.speed.actualSteps))")

        self.processingCommand = command
        scheduledCommands.removeFirst()
        speedChangeTimer?.invalidate()
        speedChangeTimer = Timer.scheduledTimer(withTimeInterval: stepDelay * BaseTimeFactor, repeats: true, block: { [weak self] timer in
            self?.speedChangeTimerFired(command: command, timer: timer)
        })
    }
    
    private func speedChangeTimerFired(command: SpeedCommand, timer: Timer) {
        // Ignore the timer if we are still waiting for a command to be completed
        // by the interface (the interface completion is necessary as it indicates
        // that the Digital Controller has processed the command).
        guard command.waitingForCompletionFromInterface == false else {
            return
        }
        
        let steps = command.steps.removeFirst()
        if command.steps.isEmpty {
            command.status = .finished
            timer.invalidate()
        }
        
        let value = interface.speedValue(for: steps, decoder: train.decoder)
        let speedKph = train.speed.speedKph(for: steps)
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} 􀐫 speed command for \(speedKph) kph (value=\(value), \(steps)), requested \(command.requestedKph) kph, status: \(command.status, privacy: .public)")
        
        assert(command.waitingForCompletionFromInterface == false)
        command.waitingForCompletionFromInterface = true
        interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: value)) { [weak self] in
            command.waitingForCompletionFromInterface = false
            self?.speedCommandExecuted(command: command, steps: steps)
        }
    }
        
    private func speedCommandExecuted(command: SpeedCommand, steps: SpeedStep) {
        train.speed.actualSteps = steps
        let speedKph = train.speed.speedKph(for: steps)
        
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} 􀆅 speed command for \(speedKph) kph (\(steps)), requested \(command.requestedKph) kph, status: \(command.status, privacy: .public)")

        processSpeedCommand(command: command)
    }
        
    private func processSpeedCommand(command: SpeedCommand) {
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} processing command \(command.requestedKph) kph, status: \(command.status, privacy: .public)")

        if command.status == .finished || command.status == .cancelled {
            let finished = command.status == .finished
            if train.speed.actualSteps == .zero && finished {
                /// Settle only if the train stopped and the speed change hasn't been cancelled.
                /// Note: see comment in ``TrainControllerAcceleration/StopSettleDelayTimer``
                stopSettleDelayTimer.schedule(train: train, completed: finished) { [weak self] completed in
                    self?.cleanupSpeedCommand(command: command)
                }
            } else {
                cleanupSpeedCommand(command: command)
            }
        }
    }
    
    private func cleanupSpeedCommand(command: SpeedCommand) {
        command.completionBlocks.forEach { $0(command.status == .finished) }
        processingCommand = nil
        executePendingSpeedChangeCommand()
    }
            
    private func speedCommands(from fromStep: SpeedStep, to toStep: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration) -> [SpeedStep] {
        guard acceleration != .none else {
            return [toStep]
        }
        
        // The number of steps to increment when changing the speed
        let stepIncrement = train.speed.accelerationStepSize ?? TrainSpeedManager.DefaultStepSize

        let actual = fromStep
        let desired = toStep

        let delta = Int(desired.value) - Int(actual.value)
        if abs(delta) <= stepIncrement {
            let (value, _) = actualValue(value: Int(actual.value) + delta, accelerating: delta > 0, desired: desired)
            return [value]
        } else {
            let tf = TrainSpeedAcceleration(fromSteps: Int(actual.value), toSteps: Int(desired.value), timeIncrement: stepDelay, stepIncrement: Int(stepIncrement), type: acceleration)
            // Trigger a speed change immediately
            var commands = [SpeedStep]()
            var time = stepDelay
            while true {
                let (value, done) = actualValue(value: tf.stepValue(at: time), accelerating: delta > 0, desired: desired)
                if done {
                    commands.append(value)
                    return commands
                } else {
                    commands.append(value)
                }
                time += stepDelay
            }
        }
    }
            
    private func actualValue(value: Int, accelerating: Bool, desired: SpeedStep) -> (SpeedStep, Bool) {
        var newValue = value
        if newValue < 0 {
            newValue = 0
        } else if newValue > train.decoder.steps {
            newValue = Int(train.decoder.steps)
        }
        
        var actual = SpeedStep(value: UInt16(newValue))
        
        var done = false
        if actual.value == desired.value {
            done = true
        } else {
            if accelerating {
                if actual.value > desired.value {
                    actual = desired
                    done = true
                }
            } else {
                if actual.value < desired.value {
                    actual = desired
                    done = true
                }
            }
        }
        
        return (actual, done)
    }
    
}
