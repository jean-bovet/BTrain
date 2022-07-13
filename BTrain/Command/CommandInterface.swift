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

/// A protocol describing the behaviors of a Digital Controller without being specific to a given brand.
protocol CommandInterface: AnyObject, MetricsProvider {
            
    func connect(server: String, port: UInt16, onReady: @escaping CompletionBlock, onError: @escaping (Error) -> Void, onStop: @escaping CompletionBlock)
    
    func disconnect(_ completion: @escaping CompletionBlock)
    
    /// Executes a command by sending the appropriate message to the Digital Controller.
    ///
    /// This method is expected to invoke the ``completion`` block when the Digital Controller
    /// has sent back an acknowledgement for the command.
    ///
    /// - Parameters:
    ///   - command: the command to execute
    ///   - completion: a completion block called when the Digital Controller has acknowledged the command. The completion block should always be called in the main thread.
    func execute(command: Command, completion: CompletionBlock?)
    
    // Returns the speed value given the number of steps and the decoder type
    func speedValue(for steps: SpeedStep, decoder: DecoderType) -> SpeedValue
    
    // Returns the number of decoder steps given the speed value and decoder type
    func speedSteps(for value: SpeedValue, decoder: DecoderType) -> SpeedStep
    
    /// Register a callback that will be invoked for each feedback event
    /// - Parameter forFeedbackChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forFeedbackChange: @escaping FeedbackChangeCallback) -> UUID

    /// Register a callback that will be invoked for each speed event
    /// - Parameter forSpeedChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forSpeedChange: @escaping SpeedChangeCallback) -> UUID

    /// Register a callback that will be invoked for each direction event
    /// - Parameter forDirectionChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forDirectionChange: @escaping DirectionChangeCallback) -> UUID

    /// Register a callback that will be invoked for each turnout event
    /// - Parameter forTurnoutChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forTurnoutChange: @escaping TurnoutChangeCallback) -> UUID
    
    /// Register a callback that will be invoked for each query locomotive event
    /// - Parameter forLocomotivesQuery: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) -> UUID
    
    /// Unregisters a specified callback
    /// - Parameter uuid: the unique ID of the callback to unregister
    func unregister(uuid: UUID)
}

// The various types used in the CommandInterface
extension CommandInterface {
    
    typealias FeedbackChangeCallback = (_ deviceID: UInt16, _ contactID: UInt16, _ value: UInt8) -> Void
    typealias SpeedChangeCallback = (_ address: UInt32, _ decoderType: DecoderType?, _ value: SpeedValue, _ acknowledgment: Bool) -> Void
    typealias DirectionChangeCallback = (_ address: UInt32, _ decoderType: DecoderType?, _ direction: Command.Direction) -> Void
    typealias TurnoutChangeCallback = (_ address: CommandTurnoutAddress, _ state: UInt8, _ power: UInt8, _ acknowledgment: Bool) -> Void
    typealias QueryLocomotiveCallback = (_ locomotives: [CommandLocomotive]) -> Void

}
