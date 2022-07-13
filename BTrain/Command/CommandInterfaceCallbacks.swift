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
import OrderedCollections

/// Manages the various callbacks for a CommandInterface
final class CommandInterfaceCallbacks {
    
    final class CallbackRegistrar<T> {
        // Note: very important to keep the order in which the callback are registered because
        // this has many implications: for example, the layout controller is expecting to be
        // the first one to process changes from the layout before other components.
        private var callbacks = OrderedDictionary<UUID, T>()
        
        /// Returns an array of all the registered callbacks
        var all: [T] {
            Array(callbacks.values)
        }
        
        func register(_ callback: T) -> UUID {
            let uuid = UUID()
            callbacks[uuid] = callback
            return uuid
        }
        
        func unregister(_ id: UUID) {
            callbacks.removeValue(forKey: id)
        }
    }

    typealias FeedbackChangeCallback = (_ deviceID: UInt16, _ contactID: UInt16, _ value: UInt8) -> Void
    typealias SpeedChangeCallback = (_ address: UInt32, _ decoderType: DecoderType?, _ value: SpeedValue, _ acknowledgment: Bool) -> Void
    typealias DirectionChangeCallback = (_ address: UInt32, _ decoderType: DecoderType?, _ direction: Command.Direction) -> Void
    typealias TurnoutChangeCallback = (_ address: CommandTurnoutAddress, _ state: UInt8, _ power: UInt8, _ acknowledgment: Bool) -> Void
    typealias QueryLocomotiveCallback = (_ locomotives: [CommandLocomotive]) -> Void

    var feedbackChanges = CallbackRegistrar<FeedbackChangeCallback>()
    var speedChanges = CallbackRegistrar<SpeedChangeCallback>()
    var directionChanges = CallbackRegistrar<DirectionChangeCallback>()
    var turnoutChanges = CallbackRegistrar<TurnoutChangeCallback>()
    var locomotivesQueries = CallbackRegistrar<QueryLocomotiveCallback>()
    
    /// Register a callback that will be invoked for each feedback event
    /// - Parameter forFeedbackChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forFeedbackChange callback: @escaping FeedbackChangeCallback) -> UUID {
        return feedbackChanges.register(callback)
    }

    /// Register a callback that will be invoked for each speed event
    /// - Parameter forSpeedChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forSpeedChange callback: @escaping SpeedChangeCallback) -> UUID {
        return speedChanges.register(callback)
    }

    /// Register a callback that will be invoked for each direction event
    /// - Parameter forDirectionChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forDirectionChange callback: @escaping DirectionChangeCallback) -> UUID {
        return directionChanges.register(callback)
    }

    /// Register a callback that will be invoked for each turnout event
    /// - Parameter forTurnoutChange: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forTurnoutChange callback: @escaping TurnoutChangeCallback) -> UUID {
        return turnoutChanges.register(callback)
    }

    /// Register a callback that will be invoked for each query locomotive event
    /// - Parameter forLocomotivesQuery: the callback block
    /// - Returns: the unique ID that can be used to unregister the callback
    @discardableResult
    func register(forLocomotivesQuery callback: @escaping QueryLocomotiveCallback) -> UUID {
        return locomotivesQueries.register(callback)
    }

    /// Unregisters a specified callback
    /// - Parameter uuid: the unique ID of the callback to unregister
    func unregister(uuid: UUID) {
        feedbackChanges.unregister(uuid)
        speedChanges.unregister(uuid)
        directionChanges.unregister(uuid)
        turnoutChanges.unregister(uuid)
        locomotivesQueries.unregister(uuid)
    }
}
