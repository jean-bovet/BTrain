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
import Combine
import OrderedCollections

final class LayoutObserver {
    
    let layout: Layout
    
    private var cancellables = [AnyCancellable]()

    init(layout: Layout) {
        self.layout = layout
        
        cancellables.append(layout.$trains.dropFirst().sink(receiveValue: { [weak self] trains in
            self?.trainCallbacks.forEach { $0(trains) }
            self?.anyCallbacks.forEach { $0() }
        }))
        
        cancellables.append(layout.$blockMap.dropFirst().sink(receiveValue: { [weak self] blocks in
            // Note: need to pass the `blocks` parameter here because the layout.blocks
            // has not yet had the time to be updated
            self?.blockCallbacks.forEach { $0(blocks) }
            self?.anyCallbacks.forEach { $0() }
        }))
        
        cancellables.append(layout.$turnouts.dropFirst().sink(receiveValue: { [weak self] turnouts in
            // Note: need to pass the `turnouts` parameter here because the layout.turnouts
            // has not yet had the time to be updated
            self?.turnoutCallbacks.forEach { $0(turnouts) }
            self?.anyCallbacks.forEach { $0() }
        }))
        
        cancellables.append(layout.$transitions.dropFirst().sink(receiveValue: { [weak self] transitions in
            self?.transitionsCallbacks.forEach { $0(transitions) }
        }))

        cancellables.append(layout.$feedbacks.dropFirst().sink(receiveValue: { [weak self] feedbacks in
            self?.anyCallbacks.forEach { $0() }
        }))
    }
    
    typealias TrainChangeCallback = ([Train]) -> Void
    typealias BlockChangeCallback = (OrderedDictionary<Identifier<Block>, Block>) -> Void
    typealias TurnoutChangeCallback = ([Turnout]) -> Void
    typealias TransitionChangeCallback = ([Transition]) -> Void
    typealias AnyChangeCallback = () -> Void

    private var trainCallbacks = [TrainChangeCallback]()
    private var blockCallbacks = [BlockChangeCallback]()
    private var turnoutCallbacks = [TurnoutChangeCallback]()
    private var transitionsCallbacks = [TransitionChangeCallback]()
    private var anyCallbacks = [AnyChangeCallback]()

    func registerForTrainChange(_ callback: @escaping TrainChangeCallback) {
        trainCallbacks.append(callback)
    }
    
    func registerForBlockChange(_ callback: @escaping BlockChangeCallback) {
        blockCallbacks.append(callback)
    }
    
    func registerForTurnoutChange(_ callback: @escaping TurnoutChangeCallback) {
        turnoutCallbacks.append(callback)
    }

    func registerForTransitioChange(_ callback: @escaping TransitionChangeCallback) {
        transitionsCallbacks.append(callback)
    }

    func registerForAnyChange(_ callback: @escaping AnyChangeCallback) {
        anyCallbacks.append(callback)
    }

}
