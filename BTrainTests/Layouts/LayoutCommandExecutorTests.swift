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

class LayoutCommandExecutorTests: XCTestCase {

    func testChangeSpeed() {
        let layout = LayoutFCreator().newLayout()
        let cmd = MockCommandInterface()
        let exec = LayoutCommandExecutor(layout: layout, interface: cmd)

        let train = layout.trains[0]
        train.inertia = true
        
        assertChangeSpeedSteps(steps: 50, expectedValues: [4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 50], exec: exec, train: train, cmd: cmd)
        assertChangeSpeedSteps(steps: 48, expectedValues: [48], exec: exec, train: train, cmd: cmd)
        assertChangeSpeedSteps(steps: 0, expectedValues: [44, 40, 36, 32, 28, 24, 20, 16, 12, 8, 4, 0], exec: exec, train: train, cmd: cmd)
    }
    
    private func assertChangeSpeedSteps(steps: UInt16, expectedValues: [UInt16], exec: LayoutCommandExecutor, train: Train, cmd: MockCommandInterface) {
        let expectation = expectation(description: "Completed")
        exec.sendTrainSpeed(train: train, steps: SpeedStep(value: steps)) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertEqual(cmd.speedValues, expectedValues)
        
        cmd.speedValues.removeAll()
    }
    
    private final class MockCommandInterface: CommandInterface {
        
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
    
}
