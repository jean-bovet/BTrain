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

// This layout contains two blocks and one turnout that are
// not linked together. It is used for unit tests and functional testing
//┌─────────┐                              ┌─────────┐
//│ Block 2 │           Turnout12          │ Block 1 │
//└─────────┘                              └─────────┘
final class LayoutDCreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-d")

    var name: String {
        return "Layout D"
    }
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutDCreator.id.uuid)
        l.name = name

        // Blocks
        let b1 = Block("1", type: .free, center: CGPoint(x: 100, y: 100))
        let b2 = Block("2", type: .free, center: CGPoint(x: 300, y: 100))
        l.add([b1, b2])

        // Feedbacks
        let f11 = Feedback("f11", deviceID: 1, contactID: 1)
        let f12 = Feedback("f12", deviceID: 1, contactID: 2)
        let f21 = Feedback("f21", deviceID: 2, contactID: 1)
        let f22 = Feedback("f22", deviceID: 2, contactID: 2)
        l.assign(b1, [f11, f12])
        l.assign(b2, [f21, f22])

        // Turnouts
        let t12 = Turnout("0", type: .singleRight, address: 3, center: CGPoint(x: 200, y: 100))
        l.turnouts.append(contentsOf: [t12])
        
        // Train
        l.newTrain()
        l.newTrain()

        // Routes
        l.newRoute("0", name: "Simple Route", [(b1, .next), (b2, .next)])
        
        return l
    }
    
}
