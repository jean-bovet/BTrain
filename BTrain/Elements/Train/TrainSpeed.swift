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
    struct SpeedTableEntry: Identifiable, Codable {
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
            return steps(for: kph)
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
        
        let stepsCount = UInt16(decoderType.steps)
        for index in 0...stepsCount {
            let speedStep = SpeedStep(value: index)
            if index >= speedTable.count || speedTable[Int(index)].steps != speedStep {
                let entry = SpeedTableEntry(steps: speedStep,
                                            speed: speedKph(for: speedStep))
                speedTable.insert(entry, at: Int(index))
            }
        }
    }
    
    func interpolateSpeedTable() {
        var newSpeedValues = [TrainSpeed.UnitKph]()
        
        // Compute all the missing speed value using linear interpolation
        // Note: we assign the interpolated values to a new array in order
        // to avoid touching the speedTable during interpolation; this is because
        // the speed values are stored as UInt16 while interpolation needs Double
        // speed value to ensure complete accuracy.
        for (index, entry) in speedTable.enumerated() {
            if let speed = entry.speed {
                newSpeedValues.append(speed)
            } else if let speed = interpolatedSpeed(at: index) {
                newSpeedValues.append(speed)
            } else {
                newSpeedValues.append(0)
            }
        }
        
        // Finally assign all the new speed values to the original speed table
        for (index, speed) in newSpeedValues.enumerated() {
            speedTable[index].speed = speed
        }
    }
    
    func interpolatedSpeed(at index: Int) -> UnitKph? {
        // Find the previous non-nil entry
        var previousEntry = SpeedTableEntry(steps: .zero, speed: 0)
        var previousIndex = index - 1
        while previousIndex >= 0 {
            let entry = speedTable[previousIndex]
            if entry.speed != nil {
                previousEntry = entry
                break
            }
            previousIndex -= 1
        }
        
        // Find the next non-nil entry
        var nextEntry: SpeedTableEntry?
        var nextIndex = index
        while nextIndex < speedTable.count {
            let entry = speedTable[nextIndex]
            if entry.speed != nil {
                nextEntry = entry
                break
            }
            nextIndex += 1
        }
        
        // If there are no non-nil speed next entry, we use the
        // maximum speed specified for the maximum number of steps possible
        if nextEntry == nil {
            nextEntry = SpeedTableEntry(steps: SpeedStep(value: UInt16(speedTable.count - 1)), speed: maxSpeed)
        }
        
        guard let nextEntry = nextEntry else {
            return nil
        }
        
        let x = (Double(index) - Double(previousEntry.steps.value)) / (Double(nextEntry.steps.value) - Double(previousEntry.steps.value))
        guard !x.isNaN && !x.isInfinite else {
            BTLogger.error("Unexpected x value of \(x) for previous steps \(previousEntry.steps.value) and next steps \(nextEntry.steps.value)")
            return nil
        }
        
        guard let previousSpeed = previousEntry.speed else {
            return nil
        }

        guard let nextSpeed = nextEntry.speed else {
            return nil
        }

        let speed0 = Double(previousSpeed)
        let speed1 = Double(nextSpeed)
        
        let interpolatedSpeed = speed0 + (speed1 - speed0) * x
        return UnitKph(interpolatedSpeed)
    }
    
    func speedKph(for steps: SpeedStep) -> UnitKph {
        UnitKph(Double(maxSpeed)/Double(decoderType.steps) * Double(steps.value))
    }

    // This method returns the number of steps corresponding to the speed in kph
    // by finding the closest match in the speedTable.
    func steps(for speedKph: UnitKph) -> SpeedStep {
        if kph == 0 {
            return SpeedStep.zero
        }

        var delta = Double.greatestFiniteMagnitude
        var matchingSteps = SpeedStep.zero
        for entry in speedTable {
            if let speed = entry.speed {
                let newDelta = abs(Double(kph) - Double(speed))
                if newDelta <= delta {
                    delta = newDelta
                    matchingSteps = entry.steps
                } else if newDelta > delta {
                    return matchingSteps
                }
            }
        }
        return matchingSteps
    }
    
}

extension TrainSpeed: Codable {
    enum CodingKeys: CodingKey {
      case decoderType, kph, speedTable
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(decoderType: try container.decode(DecoderType.self, forKey: CodingKeys.decoderType))
        self.kph = try container.decode(UInt16.self, forKey: CodingKeys.kph)
        if let speedTable = try container.decodeIfPresent([SpeedTableEntry].self, forKey: CodingKeys.speedTable) {
            self.speedTable = speedTable
        } else {
            updateSpeedStepsTable()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(decoderType, forKey: CodingKeys.decoderType)
        try container.encode(kph, forKey: CodingKeys.kph)
        try container.encode(speedTable, forKey: CodingKeys.speedTable)
    }
}
