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
    func newTurnout(name: String, category: Turnout.Category) -> Turnout {
        let turnout = Turnout(id: LayoutIdentity.newIdentity(turnouts, prefix: .turnout), name: name)
        turnout.category = category
        turnout.address = CommandTurnoutAddress(0, .MM)
        turnout.center = .init(x: 100, y: 100)
        turnouts.append(turnout)
        return turnout
    }

    func duplicate(turnoutID: Identifier<Turnout>) {
        guard let turnout = turnout(for: turnoutID) else {
            return
        }
        
        let nt = newTurnout(name: "\(turnout.name) copy", category: turnout.category)
        nt.address = turnout.address
        nt.address2 = turnout.address2
        nt.length = turnout.length
        nt.center = turnout.center.translatedBy(x: 50, y: 50)
        nt.rotationAngle = turnout.rotationAngle
        nt.stateSpeedLimit = turnout.stateSpeedLimit
    }
    
    func remove(turnoutID: Identifier<Turnout>) {
        turnouts.removeAll(where: { $0.id == turnoutID })
        
        transitions.removeAll { transition in
            transition.a.turnout == turnoutID ||
                    transition.b.turnout == turnoutID
        }
    }

    func turnout(for id: Identifier<Turnout>?) -> Turnout? {
        turnouts.first(where: { $0.id == id })
    }

    func sortTurnouts() {
        turnouts.sort {
            $0.name < $1.name
        }
    }
    
}
