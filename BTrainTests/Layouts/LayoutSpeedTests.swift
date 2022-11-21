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

final class LayoutSpeedTests: XCTestCase {
    lazy var doc = LayoutDocument(layout: LayoutLoopWithStation().newLayout())
    lazy var layout = doc.layout
    lazy var train = layout.trains[0]

    lazy var controller = doc.layoutController.trainController(forTrain: train)!
    lazy var layoutSpeed = LayoutSpeed(layout: layout)

    lazy var s1 = layout.block(named: "s1")
    lazy var s2 = layout.block(named: "s2")

    lazy var b1 = layout.block(named: "b1")
    lazy var b2 = layout.block(named: "b2")
    lazy var b3 = layout.block(named: "b3")

    lazy var t1 = layout.turnout(named: "t1")
    lazy var t2 = layout.turnout(named: "t2")
    lazy var t3 = layout.turnout(named: "t3")
    lazy var t4 = layout.turnout(named: "t4")

    override func setUp() async throws {
        try layout.setTrainToBlock(train.id, s1.id, direction: .next)
    }

    func testOccupiedSpeedLimit() throws {
        train.occupied.clear()
        train.occupied.append(s1)
        train.occupied.append(t1)
        train.occupied.append(t2)
        train.occupied.append(b1)

        train.leading.clear()
        train.leading.append(t4)
        train.leading.append(s2)

        train.leading.updateSettledDistance()

        XCTAssertEqual(train.leading.settledDistance, 115)
        XCTAssertEqual(try layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultMaximumSpeed)

        // Now let's change the occupied block to test a turnout with a limited speed branch
        train.occupied.clear()
        train.occupied.append(s1)
        train.occupied.append(t1)
        train.occupied.append(b2)

        train.leading.clear()
        train.leading.append(t3)
        train.leading.append(b3)

        t1.setStateSafe(.branchRight)
        XCTAssertEqual(train.leading.settledDistance, 115)
        XCTAssertEqual(try layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
    }

    func testLeadMaximumSpeed() throws {
        train.occupied.clear()
        train.occupied.append(s1)

        train.leading.clear()
        train.leading.append(t1)
        train.leading.append(t2)
        train.leading.append(b3)

        train.leading.updateSettledDistance()

        XCTAssertEqual(train.leading.settledDistance, 130)
        XCTAssertEqual(try layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultMaximumSpeed)

        train.leading.clear()
        train.leading.append(t1)
        train.leading.append(b2)

        // TODO: position
//        try layout.setTrainToBlock(train.id, s1.id, position: .custom(value: 1), direction: .next)

        t1.requestedState = .branchRight
        train.leading.updateSettledDistance()

        XCTAssertEqual(train.leading.settledDistance, 0)
        XCTAssertEqual(try layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultBrakingSpeed)

        t1.actualState = .branchRight
        t1.requestedState = .branchRight
        train.leading.updateSettledDistance()

        XCTAssertEqual(train.leading.settledDistance, 115)
        // Because although t1 has settled, the .branchRight has a limited speed
        XCTAssertEqual(try layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
    }

    func testBlockSpeedLimit() throws {
        train.leading.append(s1)
        train.leading.append(b1)
        train.leading.updateSettledDistance()

        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultMaximumSpeed)

        s1.speedLimit = .limited
        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
    }

    func testTurnoutSpeedLimit() throws {
        train.leading.append(t1)
        train.leading.append(t2)
        train.leading.append(b1)
        train.leading.updateSettledDistance()
        XCTAssertEqual(train.leading.settledDistance, 130)

        let route = layout.newRoute(id: "s1-b2", [(s1.id.uuid, .next), (b2.id.uuid, .next)])

        try doc.start(train: train.id, withRoute: route.id, destination: .init(b2.id, direction: .next))

        t1.requestedState = .branchRight
        train.leading.updateSettledDistance()
        XCTAssertEqual(train.leading.settledDistance, 0)

        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)

        // Settle manually turnout t1 so we can test the speed limit of the turnout in branch-right state.
        t1.actualState = t1.requestedState
        train.leading.updateSettledDistance()
        XCTAssertEqual(train.leading.settledDistance, 115)

        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
    }

    func testEdgeCases() throws {
        // TODO: position
//        XCTAssertEqual(train.leading.settledDistance, 0)
//        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultLimitedSpeed)
//
//        s1.length = 200
//        s1.feedbacks[1].distance = 130
//        try layout.setTrainToBlock(train.id, s1.id, position: .custom(value: 1), direction: .next)
//        XCTAssertEqual(train.leading.settledDistance, 0)
//        XCTAssertEqual(s1.distanceLeftInBlock(train: train), 70)
//        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), LayoutFactory.DefaultBrakingSpeed)
//
//        s1.length = 0
//        try layout.setTrainToBlock(train.id, s1.id, position: .end, direction: .next)
//        XCTAssertEqual(train.leading.settledDistance, 0)
//        XCTAssertEqual(s1.distanceLeftInBlock(train: train), 0)
//        XCTAssertEqual(try controller.layoutSpeed.maximumSpeedAllowed(train: train), 0)
    }

    func testComputation() {
        let tspeed = train.speed!

        let duration = LayoutSpeed.durationToChange(speed: tspeed, fromSpeed: LayoutFactory.DefaultMaximumSpeed, toSpeed: LayoutFactory.DefaultBrakingSpeed)
        XCTAssertEqual(duration, 2.85, accuracy: 0.1)

        let distance = LayoutSpeed.distance(atSpeed: LayoutFactory.DefaultMaximumSpeed, forDuration: duration)
        XCTAssertEqual(distance, 109, accuracy: 0.5)

        let speed = LayoutSpeed.speedToMove(distance: distance, forDuration: duration)
        XCTAssertEqual(speed, LayoutFactory.DefaultMaximumSpeed)
    }
}
