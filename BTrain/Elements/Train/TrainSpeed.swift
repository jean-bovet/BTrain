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
import SwiftCubicSpline

// This class handles the speed of a train. The speed is always expressed in kph.
final class TrainSpeed: ObservableObject, Equatable, CustomStringConvertible {
    
    // Type definition for the speed
    typealias UnitKph = UInt16

    // A speed equality is using only the kph value
    static func == (lhs: TrainSpeed, rhs: TrainSpeed) -> Bool {
        return lhs.kph == rhs.kph
    }
        
    // The speed expressed in kilometer per hour (kph).
    @Published var kph: UnitKph = 0 {
        didSet {
            if kph > maxSpeed {
                kph = maxSpeed
            }
        }
    }
    
    // Maximum speed of the train in kph
    @Published var maxSpeed: UnitKph = 200
        
    // Structure defining the number of steps corresponding
    // to a particular speed in kph.
    struct SpeedTableEntry: Identifiable {
        var id: UInt16 {
            return steps.value
        }
        
        var steps: SpeedStep
        
        // The real speed in km/h or nil if the speed hasn't been defined.
        // If nil, this speed will be interpolated given the other data point.
        var speed: UnitKph?
    }

    // Array of correspondance between the number of steps
    // and the speed in kph. The number of steps is dependent
    // on the type of decoder.
    @Published var speedTable = [SpeedTableEntry]()
        
    // The decoder type, which is used to derive the `steps` and `value` parameters
    var decoderType: DecoderType {
        didSet {
            updateSpeedStepsTable()
        }
    }
        
    // Number of steps, for the current encoder type, corresponding to the current kph value.
    // Note: the steps are always converted from/to the underlying kph value.
    var steps: SpeedStep {
        get {
            // Use a cublic spline interpolation to get the most accurate steps number.
            let points: [Point] = speedTable.compactMap { speedEntry in
                if let speed = speedEntry.speed {
                    return Point(x: Double(speed), y: Double(speedEntry.steps.value))
                } else {
                    return nil
                }
            }
            if points.count > 1 {
                let csp = CubicSpline(points: points)
                return SpeedStep(value: UInt16(csp[x: Double(kph)]))
            } else {
                return SpeedStep(value: 0)
            }
        }
        set {
            if newValue.value == 0 {
                kph = 0
            } else if newValue.value < speedTable.count - 1 {
                kph = speedTable[Int(newValue.value)].speed ?? speedKph(for: newValue)
            } else {
                kph = speedTable.last?.speed ?? maxSpeed
            }
        }
    }

    var description: String {
        return "\(kph) kph"
    }

    init(decoderType: DecoderType) {
        self.decoderType = decoderType
    }
    
    convenience init(kph: UInt16, decoderType: DecoderType) {
        self.init(decoderType: decoderType)
        self.updateSpeedStepsTable()
        self.kph = kph
    }

    convenience init(steps: SpeedStep, decoderType: DecoderType) {
        self.init(decoderType: decoderType)
        self.updateSpeedStepsTable()
        self.steps = steps
    }

    func updateSpeedStepsTable() {
        // Reset the table if the number of steps have changed,
        // usually when the decoder type has been changed.
        // Note: +1 to account for 0 steps
        if speedTable.count != decoderType.steps + 1 {
            speedTable.removeAll()
        }
        
        // Always sort the table by ascending order of the number of steps
        speedTable.sort { ss1, ss2 in
            return ss1.steps.value < ss2.steps.value
        }
        
        let stepsCount: UInt16 = UInt16(decoderType.steps)
        for index in 0...stepsCount {
            let speedStep = SpeedStep(value: index)
            if index >= speedTable.count || speedTable[Int(index)].steps != speedStep {
                let entry = SpeedTableEntry(steps: speedStep,
                                            speed: speedKph(for: speedStep))
                speedTable.insert(entry, at: Int(index))
            }
        }
    }
    
    func speedKph(for steps: SpeedStep) -> UnitKph {
        UnitKph(Double(maxSpeed)/Double(decoderType.steps) * Double(steps.value))
    }

}

extension TrainSpeed: Codable {
    enum CodingKeys: CodingKey {
      case decoderType, kph
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(decoderType: try container.decode(DecoderType.self, forKey: CodingKeys.decoderType))
        self.updateSpeedStepsTable()
        self.kph = try container.decode(UInt16.self, forKey: CodingKeys.kph)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(decoderType, forKey: CodingKeys.decoderType)
        try container.encode(kph, forKey: CodingKeys.kph)
    }
}
