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
    
    var locomotives: [Locomotive] {
        get {
            locomotiveMap.values.map {
                $0
            }
        }
        set {
            locomotiveMap.removeAll()
            newValue.forEach { locomotiveMap[$0.id] = $0 }
        }
    }

    @discardableResult
    func newLocomotive() -> Locomotive {
        let id = LayoutIdentity.newIdentity(locomotives, prefix: .locomotive)
        return addLocomotive(Locomotive(id: id, name: id.uuid, address: 0))
    }

    @discardableResult
    func addLocomotive(_ loc: Locomotive) -> Locomotive {
        locomotives.append(loc)
        return loc
    }

    func delete(locId: Identifier<Locomotive>) {
        locomotiveMap.removeValue(forKey: locId)
    }

    func removeAllLocomotives() {
        // TODO: remove also from the train
        locomotiveMap.removeAll()
    }
    
    func locomotive(for locomotiveId: Identifier<Locomotive>?) -> Locomotive? {
        guard let locomotiveId = locomotiveId else {
            return nil
        }
        return locomotiveMap[locomotiveId]
    }

    func train(forLocomotive locomotive: Locomotive) -> Train? {
        trains.first { train in
            train.locomotive?.id == locomotive.id
        }
    }
}