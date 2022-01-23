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

// This class defines the speed of a train. The speed can be expressed either in kph
// or number of steps which depends on the decoder type.
final class TrainSpeed: ObservableObject, Equatable, CustomStringConvertible {
    
    // Type definition for the speed
    typealias UnitKph = UInt16

    // A speed equality is using only the kph value
    static func == (lhs: TrainSpeed, rhs: TrainSpeed) -> Bool {
        return lhs.kph == rhs.kph
    }
        
    // The decoder type, which is used to derive the `steps` and `value` parameters
    var decoderType: DecoderType {
        didSet {
            updateSpeedStepsTable()
        }
    }
        
    // The speed express in kilometer per hour (kph).
    @Published var kph: UnitKph = 0 {
        didSet {
            if kph > maxSpeed {
                kph = maxSpeed
            }
        }
    }
    
    // Maximum speed of the train in kph
    @Published var maxSpeed: UnitKph = 200
        
    // Number of steps, for the current encoder type, corresponding to the current kph value.
    var steps: SpeedStep {
        get {
            // Use a cublic spline interpolation to get the most accurate steps number.
            let csp = CubicSpline(x: speedTable.map { Double($0.speed) },
                                  y: speedTable.map { Double($0.steps.value) })
            return SpeedStep(value: UInt16(csp[x: Double(kph)]))
        }
        set {
            if newValue.value < speedTable.count - 1 {
                kph = speedTable[Int(newValue.value)].speed
            } else {
                kph = speedTable.last?.speed ?? 0
            }
        }
    }

    // Structure defining the number of steps corresponding
    // to a particular speed in kph.
    struct SpeedTableEntry: Identifiable {
        var id: UInt16 {
            return steps.value
        }
        
        var steps: SpeedStep
        var speed: UnitKph
    }

    // Array of correspondance between the number of steps
    // and the speed in kph. The number of steps is dependent
    // on the type of decoder.
    @Published var speedTable = [SpeedTableEntry]()
        
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
        
        let stepsCount = decoderType.steps
        for index in 0...stepsCount {
            let speedStep = SpeedStep(value: UInt16(index))
            if index >= speedTable.count || speedTable[Int(index)].steps != speedStep {
                let entry = SpeedTableEntry(steps: speedStep,
                                            speed: UnitKph(Double(maxSpeed)/Double(stepsCount) * Double(index)))
                speedTable.insert(entry, at: Int(index))
            }
        }
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
