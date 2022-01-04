//
//  SimulatorViewTests.swift
//  BTrainTests
//
//  Created by Jean Bovet on 1/4/22.
//

import XCTest
import ViewInspector

@testable import BTrain

extension SimulatorView: Inspectable { }
extension SimulatorTrainControlView: Inspectable { }

class SimulatorViewTests: RootViewTests {

    func testSimulatorView() throws {
        let trains = doc.layout.mutableTrains
        XCTAssertFalse(trains.isEmpty)
        
        let t1 = trains[0]
        t1.blockId = doc.layout.blockIds[0]
        XCTAssertTrue(t1.directionForward)
        XCTAssertEqual(t1.speed, 0)
        
        connectToSimulator()
                
        // Ensure all the names of the train match.
        let sut = OverviewView(document: doc)
        let simulatorView = try sut.inspect().find(SimulatorView.self)
        let forEachView = try simulatorView.find(ViewType.ForEach.self)
        XCTAssertEqual(t1.name, try forEachView.hStack(0).text(0).string())
//        for (index, train) in trains.enumerated() {
//            XCTAssertEqual(train.name, try forEachView.tupleView(index).text(0).string())
//        }
                
        // Now tap on the direction of the first train and see if it reflected in the train list
        let simulatorTrainControl = try forEachView.hStack(0).view(SimulatorTrainControlView.self, 1)
        
        let toggleButton = try simulatorTrainControl.hStack().button(0)
        
        try toggleButton.tap()
        wait(for: t1, directionForward: false)
        
        try toggleButton.tap()
        wait(for: t1, directionForward: true)
        
        let slider = try simulatorTrainControl.hStack().slider(1)
        try slider.setValue(100)
        try slider.callOnEditingChanged()
        wait(for: t1, speed: 100)
        
        try slider.setValue(0)
        try slider.callOnEditingChanged()
        wait(for: t1, speed: 0)
    }
    
    func connectToSimulator() {
        let expectation = expectation(description: "ConnectToSimulator")
        doc.connectToSimulator { error in
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0, handler: nil)
        
        doc.enable()
        
        wait(for: {
            doc.simulator.enabled
        }, timeout: 2.0)
    }
    
    func wait(for train: Train, directionForward: Bool) {
        wait(for: {
            return train.directionForward == directionForward
        }, timeout: 2.0)

        XCTAssertEqual(train.directionForward, directionForward)
    }

    func wait(for train: Train, speed: UInt16) {
        wait(for: {
            return train.speed == speed
        }, timeout: 2.0)

        XCTAssertEqual(train.speed, speed)
    }

    func wait(for block: () -> Bool, timeout: TimeInterval) {
        let current = RunLoop.current
        let startTime = Date()
        while !block() {
            current.run(until: Date(timeIntervalSinceNow: 0.250))
            if Date().timeIntervalSince(startTime) >= timeout {
                XCTFail("Time out")
                break
            }
        }
    }

}
