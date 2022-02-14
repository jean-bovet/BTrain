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

// This class is used as a proxy to the real CommandInterface implementation.
// This is to ensure that any class that need the interface can safely use this one
// without having to worry about a change in the interface implementation (when
// switching from real Digital Controller to the Simulator).
final class ProxyCommandInterface: CommandInterface {
    
    var interface: CommandInterface! {
        didSet {
            interfaceDidChange()
        }
    }
    
    private var feedbackChangeCallbacks = [FeedbackChangeCallback]()
    private var speedChangeCallbacks = [SpeedChangeCallback]()
    private var directionChangeCallbacks = [DirectionChangeCallback]()
    private var turnoutChangeCallbacks = [TurnoutChangeCallback]()
    private var queryLocomotiveChangeCallbacks = [QueryLocomotiveCallback]()

    func disconnect(_ completion: @escaping CompletionBlock) {
        interface.disconnect(completion)
    }

    func execute(command: Command, onCompletion: @escaping () -> Void) {
        interface.execute(command: command, onCompletion: onCompletion)
    }
    
    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        return interface.speedValue(for: steps, decoder: decoder)
    }
    
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        return interface.speedSteps(for: value, decoder: decoder)
    }

    func register(forFeedbackChange: @escaping FeedbackChangeCallback) {
        feedbackChangeCallbacks.append(forFeedbackChange)
        interface.register(forFeedbackChange: forFeedbackChange)
    }
    
    func register(forSpeedChange: @escaping SpeedChangeCallback) {
        speedChangeCallbacks.append(forSpeedChange)
        interface.register(forSpeedChange: forSpeedChange)
    }
    
    func register(forDirectionChange: @escaping DirectionChangeCallback) {
        directionChangeCallbacks.append(forDirectionChange)
        interface.register(forDirectionChange: forDirectionChange)
    }
    
    func register(forTurnoutChange: @escaping TurnoutChangeCallback) {
        turnoutChangeCallbacks.append(forTurnoutChange)
        interface.register(forTurnoutChange: forTurnoutChange)
    }
        
    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) {
        queryLocomotiveChangeCallbacks.append(callback)
        interface.register(forLocomotivesQuery: callback)
    }
    
    private func interfaceDidChange() {
        feedbackChangeCallbacks.forEach { interface.register(forFeedbackChange: $0) }
        speedChangeCallbacks.forEach { interface.register(forSpeedChange: $0) }
        directionChangeCallbacks.forEach { interface.register(forDirectionChange: $0) }
        turnoutChangeCallbacks.forEach { interface.register(forTurnoutChange: $0) }
        queryLocomotiveChangeCallbacks.forEach { interface.register(forLocomotivesQuery: $0) }
    }
}
