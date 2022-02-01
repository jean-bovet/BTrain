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
    
    var interface: CommandInterface?
    
    func disconnect(_ completion: @escaping CompletionBlock) {
        interface?.disconnect(completion)
    }

    func execute(command: Command, onCompletion: @escaping () -> Void) {
        interface?.execute(command: command, onCompletion: onCompletion)
    }
    
    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue {
        return interface?.speedValue(for: steps, decoder: decoder) ?? .zero
    }
    
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep {
        return interface?.speedSteps(for: value, decoder: decoder) ?? .zero
    }

    func register(forFeedbackChange: @escaping FeedbackChangeCallback) {
        interface?.register(forFeedbackChange: forFeedbackChange)
    }
    
    func register(forSpeedChange: @escaping SpeedChangeCallback) {
        interface?.register(forSpeedChange: forSpeedChange)
    }
    
    func register(forDirectionChange: @escaping DirectionChangeCallback) {
        interface?.register(forDirectionChange: forDirectionChange)
    }
    
    func register(forTurnoutChange: @escaping TurnoutChangeCallback) {
        interface?.register(forTurnoutChange: forTurnoutChange)
    }
        
    func queryLocomotives(command: Command, completion: @escaping QueryLocomotiveCommandCompletion) {
        interface?.queryLocomotives(command: command, completion: completion)
    }
    
}
