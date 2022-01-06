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

extension Layout {
    
    @discardableResult
    func newTrain() -> Train {
        return newTrain(Layout.newIdentity(trains), name: id.uuid)
    }
    
    @discardableResult
    func newTrain(_ id: String, name: String, address: CommandLocomotiveAddress = .init(0, .MFX)) -> Train {
        let train = Train(uuid: id)
        train.name = name
        train.address = address
        trains.append(train)
        return train
    }

    func train(for trainId: Identifier<Train>?) -> Train? {
        return trains.first(where: { $0.id == trainId })
    }

    func remove(trainId: Identifier<Train>) {
        try? free(trainID: trainId, removeFromLayout: true)
        trains.removeAll(where: { $0.id == trainId})
    }
    
    func sortTrains() {
        trains.sort {
            $0.name < $1.name
        }
    }

    func freeAllTrains(removeFromLayout: Bool) {
        trains.forEach {
            try? free(trainID: $0.id, removeFromLayout: removeFromLayout)
        }
    }
}
