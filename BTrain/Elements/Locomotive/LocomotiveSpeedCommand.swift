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

/// Defines a single speed change command
final class LocomotiveSpeedCommand {
    /// The unique identifier of this command
    let requestUUID: Int

    /// The requested speed
    let requestedKph: SpeedKph

    /// The requested steps
    let requestedSteps: SpeedStep

    /// The requested acceleration
    let acceleration: LocomotiveSpeedAcceleration.Acceleration

    /// An array of speed step that need to be sent to the Digital Controller
    /// in order to change the speed of the locomotive according to the acceleration profile.
    var steps: [SpeedStep]

    /// A list of completion blocks to invoke after this speed command has completed
    var completionBlocks = [CompletionCancelBlock]()

    /// The status of the speed change callback
    enum Status: CustomStringConvertible {
        /// The speed change has not yet been executed
        case pending

        /// The speed change has been cancelled
        case cancelled

        /// The speed change has completed
        case finished

        /// The speed change is in progress
        case working

        var description: String {
            switch self {
            case .pending:
                return "pending"
            case .cancelled:
                return "cancelled"
            case .finished:
                return "finished"
            case .working:
                return "working"
            }
        }
    }

    /// The status of this command
    var status: Status = .pending

    /// True if the command is being processed by the Digital Controller.
    var isProcessedByDigitalController = false

    /// True if the command is running, false otherwise. A command is running from
    /// the time it is executed until it has finished all its commands, including
    /// the stop settled timer if applicable.
    var running = false

    init(requestUUID: Int, requestedKph: SpeedKph, requestedSteps: SpeedStep, acceleration: LocomotiveSpeedAcceleration.Acceleration, steps: [SpeedStep], completion: CompletionCancelBlock?) {
        self.requestUUID = requestUUID
        self.requestedKph = requestedKph
        self.requestedSteps = requestedSteps
        self.acceleration = acceleration
        self.steps = steps
        if let completion = completion {
            completionBlocks.append(completion)
        }
    }
}
