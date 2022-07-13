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
    
    /// Returns the callbacks available for the command interface
    var callbacks: CommandInterfaceCallbacks { get }
    
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
}
