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

import ViewInspector
import XCTest

@testable import BTrain

extension SimulatorView: Inspectable {}
extension SimulatorTrainControlView: Inspectable {}

class SimulatorViewTests: RootViewTests {
    func testSimulatorView() throws {
        let doc = newDocument()
        let trains = doc.layout.trains
        XCTAssertFalse(trains.elements.isEmpty)

        let t1 = trains[0]
        t1.locomotive?.allowedDirections = .any
        t1.speed!.accelerationProfile = .none
        t1.blockId = doc.layout.blocks.elements[0].id
        doc.layout.blocks[0].trainInstance = .init(t1.id, .next)

        XCTAssertTrue(t1.directionForward)
        XCTAssertEqual(t1.speed!.requestedKph, 0)

        connectToSimulator(doc: doc)
        defer {
            disconnectFromSimulator(doc: doc)
        }

        let simulatorTrain1 = doc.simulator.locomotives[0]

        // Ensure all the names of the train match.
        let sut = DocumentView(document: doc)
        sut.showSimulator = true
        let simulatorView = try sut.inspect().find(SimulatorView.self)
        let forEachView = try simulatorView.find(ViewType.ForEach.self)

        let simulatorTrainControl = try forEachView.view(SimulatorTrainControlView.self, 0)

        XCTAssertEqual(t1.name, try simulatorTrainControl.hStack().toggle(0).labelView().text().string())

        // Now tap on the direction of the first train and see if it is reflected in the train list
        let toggleButton = try simulatorTrainControl.hStack().group(1).button(0)

        try toggleButton.tap()
        XCTAssertFalse(simulatorTrain1.directionForward)
        wait(for: t1.locomotive!, directionForward: false)

        try toggleButton.tap()
        XCTAssertTrue(simulatorTrain1.directionForward)
        wait(for: t1.locomotive!, directionForward: true)

        // Now tap on the direction of the first train in the train list and see if it is reflected in the simulator
        let trainSpeedView = try sut.inspect().find(TrainControlSpeedView.self)
        let trainToggleButton = try trainSpeedView.vStack().hStack(0).button(0)

        try trainToggleButton.tap()
        wait(for: {
            t1.directionForward == false
        }, timeout: 0.1)

        XCTAssertFalse(t1.directionForward)
        wait(for: simulatorTrain1, directionForward: false)

        try trainToggleButton.tap()
        wait(for: {
            t1.directionForward == true
        }, timeout: 0.1)

        XCTAssertTrue(t1.directionForward)
        wait(for: simulatorTrain1, directionForward: true)

        // Change the speed of the first train and see if it is reflected in the train list
        let slider = try simulatorTrainControl.hStack().group(1).hStack(1).slider(0)
        try slider.setValue(100)
        try slider.callOnEditingChanged()
        // Note: for some reason, setting the slider.setValue(100)
        // does not set it to 100 but to its max value, 200 (maxSpeed)
        wait(for: t1.locomotive!, kph: t1.speed!.maxSpeed)

        try slider.setValue(0)
        try slider.callOnEditingChanged()
        wait(for: t1.locomotive!, kph: 0)

        // Same speed check but from the train list
        let trainSlider = try trainSpeedView.find(SpeedSlider.self).actualView()
        trainSlider.setRequestedKph(kph: 200)
        XCTAssertEqual(t1.speed!.requestedKph, t1.speed!.maxSpeed)
        wait(for: simulatorTrain1, steps: t1.speed!.requestedSteps)

        trainSlider.setRequestedKph(kph: 0)
        XCTAssertEqual(t1.speed!.requestedKph, 0)
        wait(for: simulatorTrain1, steps: .zero)
    }

    func wait(for train: Locomotive, directionForward: Bool) {
        wait(for: {
            train.directionForward == directionForward
        }, timeout: 2.0)

        XCTAssertEqual(train.directionForward, directionForward)
    }

    func wait(for train: SimulatorLocomotive, directionForward: Bool) {
        wait(for: {
            train.directionForward == directionForward
        }, timeout: 2.0)

        XCTAssertEqual(train.directionForward, directionForward)
    }

    func wait(for train: Locomotive, kph: SpeedKph) {
        wait(for: {
            train.speed.actualKph == kph
        }, timeout: 2.0)

        XCTAssertEqual(train.speed.actualKph, kph)
    }

    func wait(for train: SimulatorLocomotive, steps: SpeedStep) {
        wait(for: {
            train.speed == steps
        }, timeout: 2.0)

        XCTAssertEqual(train.speed, steps)
    }
}
