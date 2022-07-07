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
            
    /// The delay between step increments, recommended to be about 100ms.
    var stepDelay: TimeInterval {
        if let delay = train.speed.accelerationStepDelay {
            return Double(delay) / 1000
        } else {
            return Double(TrainSpeedManager.DefaultStepDelay) / 1000
        }
    }
    
    /// An array of speed commands waiting to be executed.
    /// Note that as soon as more than one command is queued,
    /// the first commands are cancelled in order to honor always
    /// the latest command being queued up.
    var commandQueue = [TrainSpeedCommand]()

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
        let command = newSpeedChangeCommand(acceleration: acceleration, completion: completion)
        commandQueue.append(command)
        
        processCommands()
    }
    
    private func processCommands() {
        guard let command = commandQueue.first else {
            return
        }
        
        // The first command should be cancelled as soon as more
        // commands are queued up, because we only want the last
        // speed command to be honored.
        let shouldCancelFirstCommand = commandQueue.count > 1
        
        switch command.status {
        case .pending:
            if train.speed.actualKph == command.requestedKph {
                command.status = .finished
                processCommands()
            } else if shouldCancelFirstCommand {
                command.status = .cancelled
                processCommands()
            } else {
                executeSpeedChangeCommand(command)
            }
            
        case .finished, .cancelled:
            // Remove the command only after it has finished running
            if command.running == false {
                command.completionBlocks.forEach { $0(command.status == .finished) }
                commandQueue.removeFirst()
                processCommands()
            }
            
        case .working:
            if shouldCancelFirstCommand {
                BTLogger.speed.debug("\(self.train, privacy: .public): cancelling in-progress speed request {\(command.requestUUID)} of \(command.requestedKph) kph")

                // Note: the next time the timer fires, the command
                // will be actually cancelled and the next command processed.
                command.status = .cancelled
            }
        }
    }
    
    /// Global UUID used to uniquely identify each speed change request in order to ease the debugging
    static var globalRequestUUID = 0
    
    private func newSpeedChangeCommand(acceleration: TrainSpeedAcceleration.Acceleration, completion: CompletionCancelBlock?) -> TrainSpeedCommand {
        TrainSpeedManager.globalRequestUUID += 1
        let requestUUID = TrainSpeedManager.globalRequestUUID

        BTLogger.speed.debug("\(self.train, privacy: .public): {\(requestUUID)} scheduling request for speed of \(self.train.speed.requestedKph) kph (\(self.train.speed.requestedSteps)) from actual speed of \(self.train.speed.actualKph) kph (\(self.train.speed.actualSteps))")

        let steps = stepsArray(from: train.speed.actualSteps, to: train.speed.requestedSteps, acceleration: acceleration)
        return TrainSpeedCommand(requestUUID: requestUUID, requestedKph: train.speed.requestedKph, requestedSteps: train.speed.requestedSteps, acceleration: acceleration, steps: steps, completion: completion)
    }
        
    private func executeSpeedChangeCommand(_ command: TrainSpeedCommand) {
        assert(command.status == .pending, "Only pending speed command can be executed!")

        BTLogger.speed.debug("\(self.train, privacy: .public): {\(command.requestUUID)} requesting speed of \(command.requestedKph) kph (\(command.requestedSteps)) from actual speed of \(self.train.speed.actualKph) kph (\(self.train.speed.actualSteps))")

        command.status = .working
        command.running = true
        speedChangeTimer?.invalidate()
        speedChangeTimer = Timer.scheduledTimer(withTimeInterval: stepDelay * BaseTimeFactor, repeats: true, block: { [weak self] timer in
            self?.speedChangeTimerFired(command: command, timer: timer)
        })
    }
    
    private func speedChangeTimerFired(command: TrainSpeedCommand, timer: Timer) {
        // Ignore the timer if we are still waiting for a command to be completed
        // by the interface (the interface completion is necessary as it indicates
        // that the Digital Controller has processed the command).
        guard command.isProcessedByDigitalController == false else {
            return
        }
        
        guard command.status != .cancelled else {
            timer.invalidate()
            speedCommandCompleted(command: command)
            return
        }
        
        assert(command.status == .working, "Only working speed command expected!")

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
        
    private func speedCommandExecuted(command: TrainSpeedCommand, steps: SpeedStep) {
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
    
    private func speedCommandCompleted(command: TrainSpeedCommand) {
        command.running = false
        processCommands()
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
