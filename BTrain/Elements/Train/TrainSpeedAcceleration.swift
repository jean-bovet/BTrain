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

final class TrainSpeedAcceleration {
    
    let fromSteps: Int
    let toSteps: Int

    let timeIncrement: TimeInterval
    let stepIncrement: Int
    
    enum Acceleration: Int, Codable, CaseIterable, CustomStringConvertible {
        case none
        case linear
        case bezier
        
        var description: String {
            switch self {
            case .none:
                return "Immediate"
                
            case .linear:
                return "Linear"
                
            case .bezier:
                return "Ease In & Out"
            }
        }
    }
    
    let acceleration: Acceleration
    
    var totalDuration: TimeInterval {
        ceil(abs(Double(toSteps) - Double(fromSteps)) / Double(stepIncrement)) * timeIncrement
    }
    
    init(fromSteps: Int, toSteps: Int, timeIncrement: TimeInterval, stepIncrement: Int, type: Acceleration) {
        self.fromSteps = fromSteps
        self.toSteps = toSteps
        self.timeIncrement = timeIncrement
        self.stepIncrement = stepIncrement
        self.acceleration = type
    }
    
    func stepValue(at time: TimeInterval) -> Int {
        switch acceleration {
        case .none:
            return toSteps
        case .linear:
            return Int(Double(fromSteps) + time / totalDuration * Double(toSteps - fromSteps))
        case .bezier:
            return Int(bézier(for: max(0, min(1, time / totalDuration)), p0: Double(fromSteps), p1: Double(fromSteps), p2: Double(toSteps), p3: Double(toSteps)))
        }
    }
    
    // https://en.wikipedia.org/wiki/Bézier_curve
    private func bézier(for t: Double, p0: Double, p1: Double, p2: Double, p3: Double) -> Double {
        pow(1-t, 3) * p0 + 3 * pow(1-t, 2) * t * p1 + 3 * (1-t) * pow(t, 2) * p2 + pow(t, 3) * p3
    }
    
}
