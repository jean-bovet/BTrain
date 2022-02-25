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

class TrainInertiaTests: XCTestCase {

    func testInertia() {
        let t = Train()
        let ic = TrainInertiaController(train: t, interface: MockCommandInterface())
        
        assertChangeSpeed(train: t, from: 0, to: 20, [4, 8, 12, 16, 20], ic)
        assertChangeSpeed(train: t, from: 20, to: 13, [16, 13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [9, 5, 1, 0], ic)
    }

    func testWithNoInertia() {
        let t = Train()
        t.inertia = false
        let ic = TrainInertiaController(train: t, interface: MockCommandInterface())

        assertChangeSpeed(train: t, from: 0, to: 20, [20], ic)
        assertChangeSpeed(train: t, from: 20, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 14, [14], ic)
        assertChangeSpeed(train: t, from: 14, to: 13, [13], ic)
        assertChangeSpeed(train: t, from: 13, to: 0, [0], ic)
    }
    
    func testActualSpeedChangeHappensAfterDigitalControllerResponse() {
        let t = Train()
        t.inertia = false
        let mi = ManualCommandInterface()
        let ic = TrainInertiaController(train: t, interface: mi)

        t.speed.requestedSteps = SpeedStep(value: 100)
        
        let expectation = expectation(description: "Completed")
        ic.applySpeed(for: t, inertia: nil) {
            expectation.fulfill()
        }
        
        wait(for: {
            mi.onCompletion != nil
        }, timeout: 1.0)
        
        // The actual speed shouldn't change yet, because the completion
        // block for the command request hasn't been invoked yet
        XCTAssertEqual(t.speed.actualSteps, .zero)
        
        mi.onCompletion!()
        // Now the actual speed should be set
        XCTAssertEqual(t.speed.requestedSteps, SpeedStep(value: 100))

        wait(for: [expectation], timeout: 2.0)
        XCTAssertEqual(t.speed.requestedSteps, SpeedStep(value: 100))
    }
    
    private func assertChangeSpeed(train: Train, from fromSteps: UInt16, to steps: UInt16, _ expectedSteps: [UInt16], _ ic: TrainInertiaController) {
        XCTAssertEqual(ic.actual.value, fromSteps)

        let cmd = ic.interface as! MockCommandInterface

        cmd.speedValues.removeAll()

        train.speed.requestedSteps = SpeedStep(value: steps)
        
        let expectation = expectation(description: "Completed")
        ic.applySpeed(for: train, inertia: nil) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        
        XCTAssertEqual(ic.desired.value, steps)
        XCTAssertEqual(ic.actual.value, steps)
        
        XCTAssertEqual(cmd.speedValues, expectedSteps)
        cmd.speedValues.removeAll()
    }
    
}

class MockCommandInterface: CommandInterface {
    
    var speedValues = [UInt16]()
    
    func connect(server: String, port: UInt16, onReady: @escaping () -> Void, onError: @escaping (Error) -> Void, onStop: @escaping () -> Void) {
        
    }
    
    func disconnect(_ completion: @escaping CompletionBlock) {
        
    }
    
    func execute(command: Command, onCompletion: @escaping () -> Void) {
        if case .speed(address: _, decoderType: _, value: let value, priority: _, descriptor: _) = command {
            speedValues.append(value.value)
        }
        DispatchQueue.main.async {
            onCompletion()
        }
    }
    
    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        return .init(value: steps.value)
    }
    
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        return .zero
    }
    
    func register(forFeedbackChange: @escaping FeedbackChangeCallback) -> UUID {
        return UUID()
    }
    
    func register(forSpeedChange: @escaping SpeedChangeCallback) {
        
    }
    
    func register(forDirectionChange: @escaping DirectionChangeCallback) {
        
    }
    
    func register(forTurnoutChange: @escaping TurnoutChangeCallback) {
        
    }
    
    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) {
        
    }
    
    func unregister(uuid: UUID) {
        
    }
            
}

class ManualCommandInterface: MockCommandInterface {
    
    var onCompletion: CompletionBlock?
    
    override func execute(command: Command, onCompletion: @escaping () -> Void) {
        self.onCompletion = onCompletion
    }
    
}
