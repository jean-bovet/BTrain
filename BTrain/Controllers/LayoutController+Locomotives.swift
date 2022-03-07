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

extension LayoutController {
        
    func discoverLocomotives(merge: Bool, completion: CompletionBlock? = nil) {
        interface.register(forLocomotivesQuery: { locomotives in
            self.process(locomotives: locomotives, merge: merge)
            completion?()
        })

        interface.execute(command: .locomotives()) { }
    }
        
    private func process(locomotives: [CommandLocomotive], merge: Bool) {
        var newTrains = [Train]()
        for loc in locomotives {
            if let locUID = loc.uid, let train = layout.trains.first(where: { $0.id.uuid == String(locUID) }), merge {
                mergeLocomotive(loc, with: train)
            } else if let locAddress = loc.address, let train = layout.trains.find(address: locAddress, decoder: loc.decoderType), merge {
                mergeLocomotive(loc, with: train)
            } else {
                let train: Train
                if let locUID = loc.uid {
                    train = Train(uuid: String(locUID))
                } else {
                    train = Train()
                }
                mergeLocomotive(loc, with: train)
                newTrains.append(train)
            }
        }
        
        if merge {
            layout.trains.append(contentsOf: newTrains)
        } else {
            layout.removeAllTrains()
            layout.trains = newTrains
        }
    }
    
    private func mergeLocomotive(_ locomotive: CommandLocomotive, with train: Train) {
        if let name = locomotive.name {
            train.name = name
        }
        if let address = locomotive.address {
            train.address = address
        }
        if let maxSpeed = locomotive.maxSpeed {
            train.speed.maxSpeed = TrainSpeed.UnitKph(maxSpeed)
        }
        train.decoder = locomotive.decoderType
    }

}
