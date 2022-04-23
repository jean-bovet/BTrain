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

// This class manages the acceleration/deceleration for a specific train. When a speed change is requested,
// this class will progressively change the speed until it reaches the requested speed value.
// The speed is incremented by a specified number of steps that is small enough to be executed
// by the Digital Controller.
final class TrainControllerAcceleration {
    
    typealias SpeedChangedCallback = (_ steps: SpeedStep, _ completed: Bool) -> Void
    
    let train: Train
    let interface: CommandInterface
    
    // The actual speed value of the locomotive (ie the last
    // speed value sent to the Digital Controller).
    var actual: SpeedStep = .zero
    
    // The desired speed value that has been requested
    var desired: SpeedStep = .zero
    
    // The number of steps to increment when changing the speed
    let stepIncrement: Int
    
    static let DefaultStepSize = 2
    
    // The delay between step increments, recommended to be about 100ms.
    let stepDelay: TimeInterval
    
    static let DefaultStepDelay = 100
    
    private var timer: Timer?
    private var currentTime: TimeInterval = 0
    private var stepsDidChange: SpeedChangedCallback?
    
    init(train: Train, interface: CommandInterface) {
        self.train = train
        self.interface = interface
        self.stepIncrement = train.speed.accelerationStepSize ?? Self.DefaultStepSize
        if let delay = train.speed.accelerationStepDelay {
            self.stepDelay = Double(delay) / 1000
        } else {
            self.stepDelay = Double(Self.DefaultStepDelay) / 1000
        }
    }
        
    func changeSpeed(of train: Train, acceleration: TrainSpeedAcceleration.Acceleration?, completion: @escaping CompletionBlock) {
        BTLogger.debug("Train \(train) request speed of \(train.speed.requestedKph) kph (\(train.speed.requestedSteps)) from actual speed of \(train.speed.actualKph) kph (\(train.speed.actualSteps))")

        changeSpeed(from: train.speed.actualSteps, to: train.speed.requestedSteps, acceleration: acceleration ?? train.speed.accelerationProfile) { [weak self] steps, finished in
            guard let interface = self?.interface else {
                return
            }
            
            let value = interface.speedValue(for: steps, decoder: train.decoder)
            BTLogger.debug("Train \(train) execute speed value \(value) (\(steps)) towards Digital Controller \(finished ? "- completed":"- in progress")")
            interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: value)) {
                // Change the actualSteps only after we know the command has been sent to the Digital Controller
                train.speed.actualSteps = steps
                BTLogger.debug("Train \(train) actual speed is \(train.speed.actualKph) kph (\(train.speed.actualSteps)) \(finished ? "- completed":"- in progress")")
                if finished {
                    if steps == .zero {
                        // When stopping a locomotive, we need to wait a bit more to ensure the locomotive
                        // has effectively stopped physically on the layout. This is because we want to callback
                        // the `completion` block only when the locomotive has stopped (otherwise, it might continue
                        // to move and activate an unexpected feedback because the layout think it has stopped already).
                        // There is unfortunately no way to know without ambiguity from the Digital Controller if the
                        // train has stopped so this extra wait time can be configured in the UX, per locomotive, and
                        // adjusted by the user depending on the locomotive speed inertia behavior.
                        DispatchQueue.main.asyncAfter(deadline: .now() + train.speed.stopSettleDelay) {
                            completion()
                        }
                    } else {
                        completion()
                    }
                }
            }
        }
    }
    
    private func changeSpeed(from fromSteps: SpeedStep, to steps: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration, callback: @escaping SpeedChangedCallback) {
        cancelPrevious()
        
        stepsDidChange = callback
        actual = fromSteps
        desired = steps

        guard acceleration != .none else {
            actual = steps
            finished()
            return
        }
        
        let delta = Int(desired.value) - Int(actual.value)
        if abs(delta) <= stepIncrement {
            setActualValue(value: Int(actual.value) + delta, accelerating: delta > 0)
        } else {
            let tf = TrainSpeedAcceleration(fromSteps: Int(actual.value), toSteps: Int(desired.value), timeIncrement: stepDelay, stepIncrement: Int(stepIncrement), type: acceleration)
            currentTime = stepDelay

            // Trigger a speed change immediately
            setActualValue(value: tf.stepValue(at: stepDelay), accelerating: delta > 0)
              
            // And scheduled the subsequent changes to be every `stepDelay` seconds.
            timer = Timer.scheduledTimer(withTimeInterval: stepDelay, repeats: true, block: { [weak self] timer in
                guard let sSelf = self else {
                    return
                }
                sSelf.currentTime += sSelf.stepDelay
                sSelf.setActualValue(value: tf.stepValue(at: sSelf.currentTime), accelerating: delta > 0)
            })
        }
    }
    
    private func setActualValue(value: Int, accelerating: Bool) {
        var newValue = value
        if newValue < 0 {
            newValue = 0
        } else if newValue > train.decoder.steps {
            newValue = Int(train.decoder.steps)
        }
        actual = SpeedStep(value: UInt16(newValue))
        
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
        
        if done {
            finished()
        } else {
            stepsDidChange?(actual, false)
        }
    }
    
    private func cancelPrevious() {
        if let stepsDidChange = stepsDidChange {
            BTLogger.debug("Interrupting in-progress speed change from \(actual.value) steps to \(desired.value) steps for \(train.name)")
            stepsDidChange(actual, true)
        }
        stepsDidChange = nil
        timer?.invalidate()
    }
    
    private func finished() {
        stepsDidChange?(actual, true)
        stepsDidChange = nil
        timer?.invalidate()
    }
}
