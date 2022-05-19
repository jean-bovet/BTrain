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

extension TrainControllerAcceleration {
    
    /// Timer that manages a change of speed value given a specific acceleration/deceleration profile.
    final class SpeedChangeTimer {
        
        typealias SpeedChangedCallback = (_ steps: SpeedStep, _ status: TrainControllerAcceleration.Status) -> Void
                        
        let train: Train
        
        // The delay between step increments, recommended to be about 100ms.
        let stepDelay: TimeInterval
        
        // The number of steps to increment when changing the speed
        let stepIncrement: Int
        
        // The actual speed value of the locomotive (ie the last
        // speed value sent to the Digital Controller).
        var actual: SpeedStep = .zero
        
        // The desired speed value that has been requested
        var desired: SpeedStep = .zero
        
        private var timer: Timer?
        private var stepsDidChange: SpeedChangedCallback?
        
        private var currentTime: TimeInterval = 0

        init(train: Train) {
            self.train = train
            self.stepIncrement = train.speed.accelerationStepSize ?? TrainControllerAcceleration.DefaultStepSize
            if let delay = train.speed.accelerationStepDelay {
                self.stepDelay = Double(delay) / 1000
            } else {
                self.stepDelay = Double(TrainControllerAcceleration.DefaultStepDelay) / 1000
            }
        }
        
        func schedule(from fromSteps: SpeedStep, to steps: SpeedStep, acceleration: TrainSpeedAcceleration.Acceleration, callback: @escaping SpeedChangedCallback) {
            assert(timer == nil)
            assert(stepsDidChange == nil)
            
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
                // Trigger a speed change immediately
                setActualValue(value: tf.stepValue(at: stepDelay), accelerating: delta > 0)
                
                // And scheduled the subsequent changes to be every `stepDelay` seconds.
                scheduleRecurringTimer(stepDelay: stepDelay, tf: tf, delta: delta)
            }
        }
        
        private func scheduleRecurringTimer(stepDelay: TimeInterval, tf: TrainSpeedAcceleration, delta: Int) {
            currentTime = stepDelay
            
            timer = Timer.scheduledTimer(withTimeInterval: stepDelay, repeats: true, block: { [weak self] timer in
                guard let sSelf = self else {
                    return
                }
                sSelf.currentTime += stepDelay
                sSelf.setActualValue(value: tf.stepValue(at: sSelf.currentTime), accelerating: delta > 0)
            })
        }
        
        func cancel() {
            if let stepsDidChange = stepsDidChange {
                BTLogger.router.warning("\(self.train, privacy: .public): interrupting in-progress speed change from \(self.actual.value) steps to \(self.desired.value) steps")
                stepsDidChange(actual, .cancelled)
            }
            stepsDidChange = nil
            timer?.invalidate()
            timer = nil
        }
        
        private func finished() {
            stepsDidChange?(actual, .finished)
            stepsDidChange = nil
            timer?.invalidate()
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
                stepsDidChange?(actual, .working)
            }
        }
        
    }
    
}
