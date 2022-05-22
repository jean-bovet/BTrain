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

@testable import BTrain

extension Turnout {
    
    func setState(_ state: State) {
        requestedState = state
        actualState = state
    }
    
    static func singleLeft() -> Turnout {
        let t1 = Turnout(name: "1")
        t1.category = .singleLeft
        t1.address = .init(1, .MM)
        t1.requestedState = .straight
        return t1
    }
    
    static func singleRight() -> Turnout {
        let t1 = Turnout(name: "1")
        t1.category = .singleRight
        t1.address = .init(1, .MM)
        t1.requestedState = .straight
        return t1
    }

    static func doubleSlip() -> Turnout {
        let t1 = Turnout(name: "1")
        t1.category = .doubleSlip
        t1.address = .init(1, .MM)
        t1.address2 = .init(2, .MM)
        t1.requestedState = .straight
        return t1
    }

    static func doubleSlip2() -> Turnout {
        let t1 = Turnout(name: "1")
        t1.category = .doubleSlip2
        t1.address = .init(1, .MM)
        t1.address2 = .init(2, .MM)
        t1.requestedState = .straight01
        return t1
    }

    static func threeWay() -> Turnout {
        let t1 = Turnout(name: "1")
        t1.category = .threeWay
        t1.address = .init(1, .MM)
        t1.address2 = .init(2, .MM)
        t1.requestedState = .straight
        return t1
    }

}

