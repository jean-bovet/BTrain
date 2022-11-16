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
    func newLocomotive() -> Locomotive {
        let id = LayoutIdentity.newIdentity(locomotives.elements, prefix: .locomotive)
        return locomotives.add(Locomotive(id: id, name: "New Locomotive", address: 0))
    }

    @discardableResult
    func duplicate(locomotive: Locomotive) -> Locomotive {
        let id = LayoutIdentity.newIdentity(locomotives.elements, prefix: .locomotive)
        let nl = locomotives.add(Locomotive(id: id, name: "\(locomotive.name) copy", address: locomotive.address, decoder: locomotive.decoder, locomotiveLength: locomotive.length, maxSpeed: locomotive.speed.maxSpeed))
        nl.speed = locomotive.speed
        locomotives.add(nl)
        return nl
    }
    
    func removeLocomotiveFromTrain(locomotive: Locomotive) {
        trains.elements.forEach { train in
            if train.locomotive == locomotive {
                train.locomotive = nil
            }
        }
    }
    
    func remove(locomotive: Locomotive) {
        removeLocomotiveFromTrain(locomotive: locomotive)
        locomotives.remove(locomotive.id)
    }
    
    func removeAllLocomotives() {
        locomotives.elements.forEach { loc in
            removeLocomotiveFromTrain(locomotive: loc)
        }
        locomotives.elements.removeAll()
    }
    
}

extension LayoutElementContainer where E == Train {
    
    subscript(identifier: Identifier<Locomotive>?) -> Train? {
      get {
          elements.first { train in
              train.locomotive?.id == identifier
          }
      }
    }

}
