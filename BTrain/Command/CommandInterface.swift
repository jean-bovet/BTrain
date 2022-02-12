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

protocol CommandInterface {
            
    func disconnect(_ completion: @escaping CompletionBlock)
    
    func execute(command: Command, onCompletion: @escaping () -> Void)
    
    // Returns the speed value given the number of steps and the decoder type
    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue
    
    // Returns the number of decoder steps given the speed value and decoder type
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep
    
    typealias FeedbackChangeCallback = (_ deviceID: UInt16, _ contactID: UInt16, _ value: UInt8) -> Void
    func register(forFeedbackChange: @escaping FeedbackChangeCallback)

    typealias SpeedChangeCallback = (_ address: UInt32, _ decoderType: DecoderType?, _ value: SpeedValue) -> Void
    func register(forSpeedChange: @escaping SpeedChangeCallback)

    typealias DirectionChangeCallback = (_ address: UInt32, _ decoderType: DecoderType?, _ direction: Command.Direction) -> Void
    func register(forDirectionChange: @escaping DirectionChangeCallback)

    typealias TurnoutChangeCallback = (_ address: CommandTurnoutAddress, _ state: UInt8, _ power: UInt8) -> Void
    func register(forTurnoutChange: @escaping TurnoutChangeCallback)
    
    typealias QueryLocomotiveCallback = (_ locomotives: [CommandLocomotive]) -> Void
    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback)
}
