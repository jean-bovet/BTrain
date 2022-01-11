//
//  TrainSpeed.swift
//  BTrain
//
//  Created by Jean Bovet on 1/10/22.
//

import Foundation
import SwiftCubicSpline

// This class handles the speed of a specific train.
// The speed can be expressed in various units:
// - kph: this is the value that is being stored on the disk
// - steps: the number of steps for the corresponding kph value, which depends on the decoder type
// - value: the value sent to the Digital Controller, which depends on the decoder type
final class TrainSpeed: ObservableObject, Equatable, Codable {
    
    // Type definition for the speed
    typealias UnitKph = UInt16
    typealias UnitStep = UInt16

    // A speed equality is using only the kph value
    static func == (lhs: TrainSpeed, rhs: TrainSpeed) -> Bool {
        return lhs.kph == rhs.kph
    }
        
    // The decoder type, which is used to derive the `steps` and `value` parameters
    var decoderType: DecoderType? {
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
    
    // TODO: read from locomotives.cs2 as well
    // Maximum speed of the train in kph
    @Published var maxSpeed: UnitKph = 200
        
    // Number of steps, for the current encoder type, corresponding to the current
    // kph value.
    var steps: UnitStep {
        get {
            // Use a cublic spline interpolation to get the most accurate steps number.
            let csp = CubicSpline(x: speedTable.map { Double($0.speed) },
                                  y: speedTable.map { Double($0.steps) })
            return TrainSpeed.UnitStep(csp[x: Double(kph)])
        }
        set {
            if newValue < speedTable.count - 1 {
                kph = speedTable[Int(newValue)].speed
            } else {
                kph = speedTable.last?.speed ?? 0
            }
        }
    }

    // Maximum value of the speed parameters that can be specified
    // in the CAN message.
    // TODO: isn't that specific to Marklin? have the interface API take
    // the number of steps and the max number of steps so it can perform
    // the calculation.
    let maxCANSpeedValue = 1000
    
    // Value to be sent to the Digital Controller. This value is derived
    // from the `steps` value and the decoder type.
    var value: UInt16 {
        get {
            guard let decoderType = decoderType else {
                return 0
            }
            
            let value = Double(steps) * Double(maxCANSpeedValue) / Double(decoderType.steps)
            return UInt16(value)
        }
        set {
            guard let decoderType = decoderType else {
                return
            }

            steps = UnitStep(Double(newValue) / Double(maxCANSpeedValue) * Double(decoderType.steps))
        }
    }
    
    // Structure defining the number of steps corresponding
    // to a particular speed in kph.
    struct SpeedStep: Identifiable {
        var id: UnitStep {
            return steps
        }
        
        var steps: UnitKph
        var speed: UnitStep
    }

    // Array of correspondance between the number of steps
    // and the speed in kph. The number of steps is dependent
    // on the type of decoder.
    @Published var speedTable = [SpeedStep]()
        
    convenience init(kph: UInt16, decoderType: DecoderType?) {
        self.init()
        self.decoderType = decoderType
        self.updateSpeedStepsTable()
        self.kph = kph
    }
    
    convenience init(value: UInt16, decoderType: DecoderType?) {
        self.init()
        self.decoderType = decoderType
        self.updateSpeedStepsTable()
        self.value = value
    }
    
    enum CodingKeys: CodingKey {
      case decoderType, kph
    }

    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.decoderType = try container.decode(DecoderType.self, forKey: CodingKeys.decoderType)
        self.updateSpeedStepsTable()
        self.kph = try container.decode(UInt16.self, forKey: CodingKeys.kph)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(decoderType, forKey: CodingKeys.decoderType)
        try container.encode(kph, forKey: CodingKeys.kph)
    }
    
    func updateSpeedStepsTable() {
        guard let decoderType = decoderType else {
            return
        }
        
        // Reset the table if the number of steps have changed,
        // usually when the decoder type has been changed.
        // Note: +1 to account for 0 steps
        if speedTable.count != decoderType.steps + 1 {
            speedTable.removeAll()
        }
        
        // Always sort the table by ascending order of the number of steps
        speedTable.sort { ss1, ss2 in
            return ss1.steps < ss2.steps
        }
        
        let stepsCount = decoderType.steps
        for index in 0...stepsCount {
            let speedStep = UnitStep(index)
            if index >= speedTable.count || speedTable[Int(index)].steps != speedStep {
                let entry = SpeedStep(steps: speedStep,
                                      speed: UnitKph(Double(maxSpeed)/Double(stepsCount) * Double(index)))
                speedTable.insert(entry, at: Int(index))
            }
        }
    }

}
