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
    
    let train: Train
    let interface: CommandInterface
        
    /// The default step size when accelerating or decelerating.
    static let DefaultStepSize = 2
    
    /// The default step delay (100ms)
    static let DefaultStepDelay = 100
    
    /// This timer is scheduled each time a speed change is requested. It will fire every `stepDelay`
    /// and send a command to the Digital Controller.
    private var speedChangeTimer: Timer?

    /// The timer that handles the delay to allow the locomotive to fully stop
    var stopSettlingDelayTimer: StopSettledDelayTimer = DefaultStopSettledDelayTimer()
        
    /// Defines a single speed change command
    final class SpeedCommand {
        
        /// The unique identifier of this command
        let requestUUID: Int
        
        /// The requested speed
        let requestedKph: TrainSpeed.UnitKph
                
        /// The requested steps
        let requestedSteps: SpeedStep
        
        /// The requested acceleration
        let acceleration: TrainSpeedAcceleration.Acceleration

        /// An array of speed step that need to be sent to the Digital Controller
        /// in order to change the speed of the train according to the acceleration profile.
        var steps: [SpeedStep]
                
        /// A list of completion blocks to invoke after this speed command has completed
        var completionBlocks = [CompletionCancelBlock]()

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
        
        /// The status of this command
        var status: Status = .working
        
        /// True if the command is being processed by the Digital Controller.
        var isProcessedByDigitalController = false

        init(requestUUID: Int, requestedKph: TrainSpeed.UnitKph, requestedSteps: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration, steps: [SpeedStep], completion: CompletionCancelBlock?) {
            self.requestUUID = requestUUID
            self.requestedKph = requestedKph
            self.requestedSteps = requestedSteps
            self.acceleration = acceleration
            self.steps = steps
            if let completion = completion {
                completionBlocks.append(completion)
            }
        }
    }
        
    /// The currently processed command. Nil if no command is in progress.
    var processingCommand: SpeedCommand?
    
    /// The next command to be executed.
    ///
    /// There is a maximum of one and only one scheduled command waiting to be executed.
    /// Any new speed change request requested is going to cancel and remove the previous
    /// scheduled command because it only makes sense to honor the latest speed change request.
    var scheduledCommand: SpeedCommand?
    
    /// The delay between step increments, recommended to be about 100ms.
    var stepDelay: TimeInterval {
        if let delay = train.speed.accelerationStepDelay {
            return Double(delay) / 1000
        } else {
            return Double(TrainSpeedManager.DefaultStepDelay) / 1000
        }
    }
    
    /// Initializes the speed manager for the specified train.
    ///
    /// - Parameters:
    ///   - train: the train
    ///   - interface: the Digital Controller interface
    ///   - speedChanged: an optional block that is invoked each time a speed change from the Digital Controller is detected.
    init(train: Train, interface: CommandInterface, speedChanged: CompletionBlock? = nil) {
        self.train = train
        self.interface = interface
        
        interface.register(forSpeedChange: { address, decoder, value, acknowledgment in
            if train.address.actualAddress(for: train.decoder) == address.actualAddress(for: decoder) {
                let steps = interface.speedSteps(for: value, decoder: train.decoder)
                if acknowledgment {
                    // Note: the `speedCommandExecuted` function below is also updating the actual steps
                    // when a speed command completion happens. This is fine because for each speed change,
                    // we need to call both the completion block and the change callback here.
                    train.speed.actualSteps = steps
                    BTLogger.speed.debug("\(train, privacy: .public): 􀝆 actual speed is \(train.speed.actualKph) kph (\(train.speed.actualSteps))")
                } else {
                    // Only a  direct command from the Digital Controller should change the requested speed.
                    train.speed.requestedSteps = steps
                    BTLogger.speed.debug("\(train, privacy: .public): 􀝆 requested speed is \(train.speed.actualKph) kph (\(train.speed.actualSteps))")
                }
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
    func changeSpeed(completion: CompletionCancelBlock? = nil) {
        changeSpeed(acceleration: train.speed.accelerationProfile, completion: completion)
    }
    
    func changeSpeed(acceleration: TrainSpeedAcceleration.Acceleration, completion: CompletionCancelBlock? = nil) {
        if let processingCommand = processingCommand {
            scheduleSpeedChangeWithProcessingCommand(processingCommand: processingCommand,
                                                     acceleration: acceleration,
                                                     completion: completion)
        } else if train.speed.actualKph == train.speed.requestedKph {
            // If there is no command in progress and the requested and actual speeds are the same,
            // nothing is needed and we can return immediately after invoked the completion block.
            completion?(true)
        } else {
            // Schedule a new speed change request
            if let _ = scheduleSpeedChangeCommand(acceleration: acceleration, completion: completion) {
                executePendingSpeedChangeCommand()
            }
        }
    }
    
    private func scheduleSpeedChangeWithProcessingCommand(processingCommand: SpeedCommand, acceleration: TrainSpeedAcceleration.Acceleration, completion: CompletionCancelBlock?) {
        if processingCommand.status == .cancelled {
            // The processing command has already been cancelled
            if train.speed.actualKph == train.speed.requestedKph {
                // If the requested and actual speeds are the same, nothing special is needed
                // and we can invoke the completion block immediately
                completion?(true)
            } else {
                // Schedule a new speed change request
                if let _ = scheduleSpeedChangeCommand(acceleration: acceleration, completion: completion) {
                    if !processingCommand.isProcessedByDigitalController {
                        // And schedule the speed change request only if there is *no* processing command
                        // still processed by the Digital Controller.
                        // Even when a command is cancelled, there is still a possibility that this command
                        // has a pending speed change being processed by the Digital Controller. This means
                        // that at some point in the future, that pending change will complete and the
                        // appropriate code will be executed.
                        executePendingSpeedChangeCommand()
                    }
                }
            }
        } else {
            // There is already a speed change command being processed (which has not been cancelled!)
            if processingCommand.requestedKph == train.speed.requestedKph {
                // If the speed change is the same and a completion block is provided,
                // add the completion block to the list of completion block of the command
                // itself. At the completion of the command, all the completion blocks will be invoked.
                if let completion = completion {
                    BTLogger.speed.debug("\(self.train, privacy: .public): attaching request to previous request {\(processingCommand.requestUUID)} because the requested speed of \(self.train.speed.requestedKph) is the same")
                    processingCommand.completionBlocks.append(completion)
                }
            } else {
                // If the speed change is different, cancel the current speed command and schedule a new one
                if let requestUUID = scheduleSpeedChangeCommand(acceleration: acceleration, completion: completion) {
                    BTLogger.speed.debug("\(self.train, privacy: .public): {\(requestUUID)} cancelling previous speed request {\(processingCommand.requestUUID)} of \(processingCommand.requestedKph) kph")
                    
                    processingCommand.status = .cancelled
                    speedChangeTimer?.invalidate()
                    
                    if !processingCommand.isProcessedByDigitalController {
                        speedCommandCompleted(command: processingCommand)
                    }
                }
            }
        }
    }
    
    private func scheduleSpeedChangeCommand(acceleration: TrainSpeedAcceleration.Acceleration, completion: CompletionCancelBlock?) -> Int? {
        if let nextCommand = scheduledCommand {
            if nextCommand.requestedKph == train.speed.requestedKph && nextCommand.acceleration == acceleration {
                // The next command to be executed is exactly the same as this potential command.
                if let completion = completion {
                    // Attach the completion block to the next command
                    BTLogger.speed.debug("\(self.train, privacy: .public): attaching request to next request {\(nextCommand.requestUUID)} because the requested speed of \(self.train.speed.requestedKph) is the same")
                    nextCommand.completionBlocks.append(completion)
                } else {
                    // Without completion block, we can simply ignore that speed change request
                }
                return nil
            } else {
                // The next command is different than the new command. Cancel the next command because it does not make sense to execute it
                // when there is a new speed change command requested.
                nextCommand.status = .cancelled
                nextCommand.completionBlocks.forEach { $0(false) }
                scheduledCommand = nil
            }
        }
        
        TrainSpeedManager.globalRequestUUID += 1
        let requestUUID = TrainSpeedManager.globalRequestUUID

        BTLogger.speed.debug("\(self.train, privacy: .public): {\(requestUUID)} scheduling request for speed of \(self.train.speed.requestedKph) kph (\(self.train.speed.requestedSteps)) from actual speed of \(self.train.speed.actualKph) kph (\(self.train.speed.actualSteps))")

        let steps = stepsArray(from: train.speed.actualSteps, to: train.speed.requestedSteps, acceleration: acceleration)
        scheduledCommand = SpeedCommand(requestUUID: requestUUID, requestedKph: train.speed.requestedKph, requestedSteps: train.speed.requestedSteps, acceleration: acceleration, steps: steps, completion: completion)
        
        return requestUUID
    }
        
    private func executePendingSpeedChangeCommand() {
        guard let command = scheduledCommand else {
            return
        }
        
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} requesting speed of \(command.requestedKph) kph (\(command.requestedSteps)) from actual speed of \(self.train.speed.actualKph) kph (\(self.train.speed.actualSteps))")

        processingCommand = command
        scheduledCommand = nil
        speedChangeTimer?.invalidate()
        speedChangeTimer = Timer.scheduledTimer(withTimeInterval: stepDelay * BaseTimeFactor, repeats: true, block: { [weak self] timer in
            self?.speedChangeTimerFired(command: command, timer: timer)
        })
    }
    
    private func speedChangeTimerFired(command: SpeedCommand, timer: Timer) {
        // Ignore the timer if we are still waiting for a command to be completed
        // by the interface (the interface completion is necessary as it indicates
        // that the Digital Controller has processed the command).
        guard command.isProcessedByDigitalController == false else {
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
        
        assert(command.isProcessedByDigitalController == false)
        command.isProcessedByDigitalController = true
        interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: value)) { [weak self] in
            command.isProcessedByDigitalController = false
            self?.speedCommandExecuted(command: command, steps: steps)
        }
    }
        
    private func speedCommandExecuted(command: SpeedCommand, steps: SpeedStep) {
        train.speed.actualSteps = steps
        
        let speedKph = train.speed.speedKph(for: steps)
        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} 􀆅 speed command for \(speedKph) kph (\(steps)), requested \(command.requestedKph) kph, status: \(command.status, privacy: .public)")

        if command.status == .finished || command.status == .cancelled {
            let finished = command.status == .finished
            if train.speed.actualSteps == .zero && finished {
                /// Settle only if the train stopped and the speed change hasn't been cancelled.
                /// Note: see comment in ``TrainControllerAcceleration/StopSettleDelayTimer``
                stopSettlingDelayTimer.schedule(train: train, completed: finished) { [weak self] completed in
                    self?.speedCommandCompleted(command: command)
                }
            } else {
                speedCommandCompleted(command: command)
            }
        }
    }
    
    private func speedCommandCompleted(command: SpeedCommand) {
        if processingCommand?.requestUUID == command.requestUUID {
            command.completionBlocks.forEach { $0(command.status == .finished) }
            processingCommand = nil
            executePendingSpeedChangeCommand()
        }
    }
            
    private func stepsArray(from fromStep: SpeedStep, to toStep: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration) -> [SpeedStep] {
        guard acceleration != .none else {
            return [toStep]
        }
        
        // The number of steps to increment when changing the speed
        let stepIncrement = train.speed.accelerationStepSize ?? TrainSpeedManager.DefaultStepSize

        let actual = fromStep
        let desired = toStep

        let delta = Int(desired.value) - Int(actual.value)
        if abs(delta) <= stepIncrement {
            let (value, _) = stepValue(value: Int(actual.value) + delta, accelerating: delta > 0, desired: desired)
            return [value]
        } else {
            let tf = TrainSpeedAcceleration(fromSteps: Int(actual.value), toSteps: Int(desired.value), timeIncrement: stepDelay, stepIncrement: Int(stepIncrement), type: acceleration)
            var commands = [SpeedStep]()
            var time = stepDelay
            while true {
                let (value, done) = stepValue(value: tf.stepValue(at: time), accelerating: delta > 0, desired: desired)
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
            
    private func stepValue(value: Int, accelerating: Bool, desired: SpeedStep) -> (SpeedStep, Bool) {
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
