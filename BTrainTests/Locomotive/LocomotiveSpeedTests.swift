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

final class LocomotiveSpeedTests: XCTestCase {
    let mi = MarklinInterface()

    func testInitialization() {
        let s1 = LocomotiveSpeed(kph: 100, decoderType: .MFX)
        assertSpeed(s1, mi, kph: 100, steps: 63, value: 500)

        let s2 = LocomotiveSpeed(steps: SpeedStep(value: 63), decoderType: .MFX)
        assertSpeed(s2, mi, kph: 100, steps: 63, value: 500)
    }

    func testConversion() {
        let loc = Locomotive(uuid: "1")
        loc.address = 0x4001

        let halfValues: [DecoderType: UInt16] = [
            .MFX: 500,
            .MM: 500,
            .MM2: 519,
            .DCC: 500,
            .SX1: 517,
        ]
        let halfKphs: [DecoderType: UInt16] = [
            .MFX: 100,
            .MM: 100,
            .MM2: 103,
            .DCC: 100,
            .SX1: 103,
        ]

        for decoder in DecoderType.allCases {
            loc.decoder = decoder
            XCTAssertEqual(loc.speed.speedTable.count, Int(loc.decoder.steps) + 1)

            let halfSteps = UInt16(ceil(Double(decoder.steps) / 2.0))
            let halfKph = halfKphs[decoder]!
            let halfValue = halfValues[decoder]!
            let maxSteps = UInt16(decoder.steps)

            loc.speed.requestedKph = .zero
            assertSpeed(loc.speed, mi, kph: 0, steps: 0, value: 0)

            loc.speed.requestedKph = 100
            assertSpeed(loc.speed, mi, kph: halfKph, steps: halfSteps, value: halfValue)

            loc.speed.requestedKph = 200
            assertSpeed(loc.speed, mi, kph: 200, steps: maxSteps, value: 1000)

            loc.speed.requestedKph = 300
            assertSpeed(loc.speed, mi, kph: 200, steps: maxSteps, value: 1000)

            loc.speed.requestedSteps = SpeedStep.zero
            assertSpeed(loc.speed, mi, kph: 0, steps: 0, value: 0)

            loc.speed.requestedSteps = SpeedStep(value: halfSteps)
            assertSpeed(loc.speed, mi, kph: halfKph, steps: halfSteps, value: halfValue)

            loc.speed.requestedSteps = SpeedStep(value: maxSteps)
            assertSpeed(loc.speed, mi, kph: 200, steps: maxSteps, value: 1000)

            loc.speed.requestedSteps = SpeedStep(value: maxSteps * 2)
            assertSpeed(loc.speed, mi, kph: 200, steps: maxSteps, value: 1000)
        }
    }

    func testConversionWithEmptyTable() {
        let loc = Locomotive(uuid: "1")
        loc.address = 0x4001

        for decoder in DecoderType.allCases {
            loc.decoder = decoder
            XCTAssertEqual(loc.speed.speedTable.count, Int(decoder.steps) + 1)

            let halfSteps = UInt16(ceil(Double(decoder.steps) / 2.0))

            loc.speed.speedTable.removeAll()

            XCTAssertTrue(loc.speed.speedTable.isEmpty)

            loc.speed.requestedKph = .zero
            XCTAssertEqual(loc.speed.requestedSteps.value, 0)
            XCTAssertEqual(loc.speed.requestedKph, 0)

            loc.speed.requestedKph = 100
            XCTAssertEqual(loc.speed.requestedSteps.value, halfSteps)

            loc.speed.requestedKph = 200
            XCTAssertEqual(loc.speed.requestedSteps.value, UInt16(decoder.steps))

            loc.speed.requestedSteps = .zero
            XCTAssertEqual(loc.speed.requestedSteps.value, 0)
            XCTAssertEqual(loc.speed.requestedKph, 0)
        }
    }

    func testConversionWithUndefinedValue() {
        let loc = Locomotive(uuid: "1")
        loc.address = 0x4001

        XCTAssertEqual(loc.speed.speedTable.count, Int(DecoderType.MFX.steps) + 1)

        let fixedSpeedStep = SpeedStep(value: 10)

        loc.speed.requestedSteps = fixedSpeedStep

        XCTAssertEqual(loc.speed.requestedSteps.value, 10)
        XCTAssertEqual(loc.speed.requestedKph, 15)

        loc.speed.speedTable[10] = .init(steps: fixedSpeedStep, speed: nil)

        loc.speed.requestedSteps = fixedSpeedStep

        XCTAssertEqual(loc.speed.requestedSteps.value, 10)
        XCTAssertEqual(loc.speed.requestedKph, 15)

        // Put back the speed value
        loc.speed.speedTable[10] = .init(steps: fixedSpeedStep, speed: 15)

        loc.speed.requestedSteps = fixedSpeedStep

        XCTAssertEqual(loc.speed.requestedSteps.value, 10)
        XCTAssertEqual(loc.speed.requestedKph, 15)
    }

    func testInterpolation() {
        let loc = Locomotive(uuid: "1")
        loc.address = 0x4001

        let speed = loc.speed
        let maxSteps = speed.speedTable.count - 1

        let expectedSpeeds = [20: [0, 1, 6, 10, 20], 140: [0, 1, 46, 70, 140], 200: [0, 1, 66, 100, 200]]
        for maxSpeed in expectedSpeeds {
            speed.setMaxSpeed(maxSpeed.key, interpolate: false)
            XCTAssertEqual(speed.interpolatedSpeed(at: 0), SpeedKph(maxSpeed.value[0]))
            XCTAssertEqual(speed.interpolatedSpeed(at: 1), SpeedKph(maxSpeed.value[1]))
            XCTAssertEqual(speed.interpolatedSpeed(at: maxSteps / 3), SpeedKph(maxSpeed.value[2]))
            XCTAssertEqual(speed.interpolatedSpeed(at: maxSteps / 2), SpeedKph(maxSpeed.value[3]))
            XCTAssertEqual(speed.interpolatedSpeed(at: maxSteps), SpeedKph(maxSpeed.value[4]))
        }

        // Assert of a few speed values
        for maxSpeed in expectedSpeeds {
            speed.setMaxSpeed(maxSpeed.key)
            XCTAssertEqual(speed.speedTable[0].speed, SpeedKph(maxSpeed.value[0]))
            XCTAssertEqual(speed.speedTable[1].speed, SpeedKph(maxSpeed.value[1]))
            XCTAssertEqual(speed.speedTable[maxSteps / 3].speed, SpeedKph(maxSpeed.value[2]))
            XCTAssertEqual(speed.speedTable[maxSteps / 2].speed, SpeedKph(maxSpeed.value[3]))
            XCTAssertEqual(speed.speedTable[maxSteps].speed, SpeedKph(maxSpeed.value[4]))
        }

        // Now assert the whole table
        speed.setMaxSpeed(200)
        for index in 0 ... maxSteps {
            XCTAssertEqual(speed.speedTable[index].speed, SpeedKph(Double(index) / Double(maxSteps) * 200), "At index \(index)")
        }
    }

    private func assertSpeed(_ speed: LocomotiveSpeed, _ interface: CommandInterface, kph: SpeedKph, steps: UInt16, value: UInt16) {
        XCTAssertEqual(speed.requestedKph, kph, "Mismatching requested kph values")
        XCTAssertEqual(speed.requestedSteps.value, steps, "Mismatching requested steps values")

        let actualValue = interface.speedValue(for: speed.requestedSteps, decoder: speed.decoderType)
        XCTAssertEqual(actualValue.value, value, "Mismatching actual values")
        XCTAssertEqual(interface.speedSteps(for: actualValue, decoder: speed.decoderType).value, steps, "Mismatching actual steps")
    }
}

private extension LocomotiveSpeed {
    func setMaxSpeed(_ speed: Int, interpolate: Bool = true) {
        maxSpeed = SpeedKph(speed)
        clearSpeedTable()
        if interpolate {
            interpolateSpeedTable()
        }
    }

    func clearSpeedTable() {
        for index in speedTable.indices {
            speedTable[index].speed = nil
        }
    }
}
