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

import XCTest

@testable import BTrain

final class TrainSpeedTests: XCTestCase {

    let mi = MarklinInterface()

    func testInitialization() {
        let s1 = TrainSpeed(kph: 100, decoderType: .MFX)
        assertSpeed(s1, mi, kph: 100, steps: 63, value: 500)
        
        let s2 = TrainSpeed(steps: SpeedStep(value: 63), decoderType: .MFX)
        assertSpeed(s2, mi, kph: 100, steps: 63, value: 500)
    }
    
    func testConversion() {
        let t1 = Train(uuid: "1")
        t1.address = 0x4001
        
        let halfValues: [DecoderType:UInt16] = [
            .MFX: 500,
            .MM: 500,
            .MM2: 519,
            .DCC: 500,
            .SX1: 517
        ]
        let halfKphs: [DecoderType:UInt16] = [
            .MFX: 100,
            .MM: 100,
            .MM2: 103,
            .DCC: 100,
            .SX1: 103
        ]

        for decoder in DecoderType.allCases {
            t1.decoder = decoder
            XCTAssertEqual(t1.speed.speedTable.count, Int(t1.decoder.steps) + 1)
            
            let halfSteps = UInt16(ceil(Double(decoder.steps)/2.0))
            let halfKph = halfKphs[decoder]!
            let halfValue = halfValues[decoder]!
            let maxSteps = UInt16(decoder.steps)
            
            t1.speed.requestedKph = .zero
            assertSpeed(t1.speed, mi, kph: 0, steps: 0, value: 0)
            
            t1.speed.requestedKph = 100
            assertSpeed(t1.speed, mi, kph: halfKph, steps: halfSteps, value: halfValue)
            
            t1.speed.requestedKph = 200
            assertSpeed(t1.speed, mi, kph: 200, steps: maxSteps, value: 1000)
            
            t1.speed.requestedKph = 300
            assertSpeed(t1.speed, mi, kph: 200, steps: maxSteps, value: 1000)
            
            t1.speed.requestedSteps = SpeedStep.zero
            assertSpeed(t1.speed, mi, kph: 0, steps: 0, value: 0)
            
            t1.speed.requestedSteps = SpeedStep(value: halfSteps)
            assertSpeed(t1.speed, mi, kph: halfKph, steps: halfSteps, value: halfValue)

            t1.speed.requestedSteps = SpeedStep(value: maxSteps)
            assertSpeed(t1.speed, mi, kph: 200, steps: maxSteps, value: 1000)

            t1.speed.requestedSteps = SpeedStep(value: maxSteps*2)
            assertSpeed(t1.speed, mi, kph: 200, steps: maxSteps, value: 1000)
        }
    }
    
    func testConversionWithEmptyTable() {
        let t1 = Train(uuid: "1")
        t1.address = 0x4001
        
        for decoder in DecoderType.allCases {
            t1.decoder = decoder
            XCTAssertEqual(t1.speed.speedTable.count, Int(decoder.steps) + 1)

            let halfSteps = UInt16(ceil(Double(decoder.steps)/2.0))

            t1.speed.speedTable.removeAll()
            
            XCTAssertTrue(t1.speed.speedTable.isEmpty)
            
            t1.speed.requestedKph = .zero
            XCTAssertEqual(t1.speed.requestedSteps.value, 0)
            XCTAssertEqual(t1.speed.requestedKph, 0)
                    
            t1.speed.requestedKph = 100
            XCTAssertEqual(t1.speed.requestedSteps.value, halfSteps)

            t1.speed.requestedKph = 200
            XCTAssertEqual(t1.speed.requestedSteps.value, UInt16(decoder.steps))
            
            t1.speed.requestedSteps = .zero
            XCTAssertEqual(t1.speed.requestedSteps.value, 0)
            XCTAssertEqual(t1.speed.requestedKph, 0)
        }
    }
    
    func testConversionWithUndefinedValue() {
        let t1 = Train(uuid: "1")
        t1.address = 0x4001
        
        XCTAssertEqual(t1.speed.speedTable.count, Int(DecoderType.MFX.steps) + 1)

        let fixedSpeedStep = SpeedStep(value: 10)
        
        t1.speed.requestedSteps = fixedSpeedStep
        
        XCTAssertEqual(t1.speed.requestedSteps.value, 10)
        XCTAssertEqual(t1.speed.requestedKph, 15)
        
        t1.speed.speedTable[10] = .init(steps: fixedSpeedStep, speed: nil)

        t1.speed.requestedSteps = fixedSpeedStep

        XCTAssertEqual(t1.speed.requestedSteps.value, 10)
        XCTAssertEqual(t1.speed.requestedKph, 15)
        
        // Put back the speed value
        t1.speed.speedTable[10] = .init(steps: fixedSpeedStep, speed: 15)

        t1.speed.requestedSteps = fixedSpeedStep

        XCTAssertEqual(t1.speed.requestedSteps.value, 10)
        XCTAssertEqual(t1.speed.requestedKph, 15)
    }
    
    func testInterpolation() {
        let t1 = Train(uuid: "1")
        t1.address = 0x4001
        
        // Empty the whole speed table of its speed value
        let speed = t1.speed
        for index in t1.speed.speedTable.indices {
            speed.speedTable[index].speed = nil
        }

        let maxSteps = speed.speedTable.count - 1
        
        XCTAssertEqual(speed.interpolatedSpeed(at: 0), 0)
        XCTAssertEqual(speed.interpolatedSpeed(at: maxSteps/3), 66)
        XCTAssertEqual(speed.interpolatedSpeed(at: maxSteps/2), 100)
        XCTAssertEqual(speed.interpolatedSpeed(at: maxSteps), 200)
        
        // Interpolate the whole table
        speed.interpolateSpeedTable()
        
        // Assert of a few speed values
        XCTAssertEqual(speed.speedTable[0].speed, 0)
        XCTAssertEqual(speed.speedTable[maxSteps/3].speed, 66)
        XCTAssertEqual(speed.speedTable[maxSteps/2].speed, 100)
        XCTAssertEqual(speed.speedTable[maxSteps].speed, 200)
        
        // Now assert the whole table
        for index in 0...maxSteps {
            XCTAssertEqual(speed.speedTable[index].speed, TrainSpeed.UnitKph(Double(index) / Double(maxSteps) * 200), "At index \(index)")
        }
    }
    
    private func assertSpeed(_ speed: TrainSpeed, _ interface: CommandInterface, kph: TrainSpeed.UnitKph, steps: UInt16, value: UInt16) {
        XCTAssertEqual(speed.requestedKph, kph, "Mismatching requested kph values")
        XCTAssertEqual(speed.requestedSteps.value, steps, "Mismatching requested steps values")
        
        let actualValue = interface.speedValue(for: speed.requestedSteps, decoder: speed.decoderType)
        XCTAssertEqual(actualValue.value, value, "Mismatching actual values")
        XCTAssertEqual(interface.speedSteps(for: actualValue, decoder: speed.decoderType).value, steps, "Mismatching actual steps")
    }
    
}
