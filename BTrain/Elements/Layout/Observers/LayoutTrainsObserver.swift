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

/// Abstract base class for any sub-class that needs to observe a particular train attribute
class LayoutTrainsObserver {
    
    let layout: Layout

    typealias TrainChangeCallback = (Train) -> Void
    private var trainCallbacks = [TrainChangeCallback]()

    private var trainsCancellable: AnyCancellable?
    private var cancellables = [AnyCancellable]()
    
    init(layout: Layout) {
        self.layout = layout
        
        trainsCancellable = layout.$trains.sink(receiveValue: { [weak self] trains in
            self?.registerForTrainsChange()
        })
    }
    
    func registerForChange(_ callback: @escaping TrainChangeCallback) {
        trainCallbacks.append(callback)
    }
    
    private func registerForTrainsChange() {
        cancellables.removeAll()
        for train in layout.trains {
            if let cancellable = registerForTrainChange(train) {
                cancellables.append(cancellable)
            }
        }
    }

    internal func trainChanged(_ train: Train) {
        trainCallbacks.forEach({$0(train)})
    }
    
    internal func registerForTrainChange(_ train: Train) -> AnyCancellable? {
        nil
    }

}

