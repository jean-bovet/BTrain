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

final class TrainInertiaController {
    
    typealias SpeedChangedCallback = (_ steps: SpeedStep, _ completed: Bool) -> Void
    
    let train: Train
    let interface: CommandInterface
    
    var actual: SpeedStep = .zero
    var desired: SpeedStep = .zero
        
    let stepIncrement = 4
    let stepDelay = 0.1
    
    private var timer: Timer?
    private var stepsDidChange: SpeedChangedCallback?
    
    init(train: Train, interface: CommandInterface) {
        self.train = train
        self.interface = interface
    }
        
    func changeSpeed(of train: Train, inertia: Bool?, completion: @escaping CompletionBlock) {
        BTLogger.debug("Train \(train.name) requested speed of \(train.speed)")

        changeSpeed(to: train.speed.requestedSteps, inertia: inertia ?? train.inertia) { [weak self] steps, finished in
            if let interface = self?.interface {
                let value = interface.speedValue(for: steps, decoder: train.decoder)
                interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: value)) {
                    // Note: change the actualSteps only after we know the command has been sent to the Digital Controller
                    BTLogger.debug("Train \(train.name) actual speed is \(train.speed)")
                    train.speed.actualSteps = steps
                    if finished {
                        completion()
                    }
                }
            }
        }
    }
    
    private func changeSpeed(to steps: SpeedStep, inertia: Bool, callback: @escaping SpeedChangedCallback) {
        cancelPrevious()
        
        stepsDidChange = callback
        desired = steps

        guard inertia else {
            actual = steps
            finished()
            return
        }
        
        let delta = Int(desired.value) - Int(actual.value)
        if abs(delta) <= stepIncrement {
            changeActual(with: delta)
        } else {
            // Trigger a speed change immediately
            changeActual(with: stepIncrement * delta.signum())
            
            // And scheduled the subsequent changes to be every `stepDelay` seconds.
            timer = Timer.scheduledTimer(withTimeInterval: stepDelay, repeats: true, block: { [weak self] timer in
                guard let sSelf = self else {
                    return
                }
                
                sSelf.changeActual(with: sSelf.stepIncrement * delta.signum())
            })
        }
    }
    
    private func changeActual(with increment: Int) {
        var newValue = Int(actual.value) + increment
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
            if increment > 0 {
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
            BTLogger.debug("Interrupting in-progress speed change for \(train.name)")
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