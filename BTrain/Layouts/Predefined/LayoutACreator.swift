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

//                 ┌─────────┐
//┌────────────────│ Block 2 │◀────────────────────┐
//│                └─────────┘                     │
//│                                                │
//│                                                │
//│                ┌─────────┐
//│       ┌───────▶│ Block 3 │────────────────▶Turnout12
//│       │        └─────────┘
//│       │                                        ▲
//│       │                                        │
//│                                 ┌─────────┐    │
//└─▶Turnout21 ────────────────────▶│ Block 1 │────┘
//                                  └─────────┘
final class LayoutACreator: LayoutCreating {

    static let id = Identifier<Layout>(uuid: "layout-a")
    
    var name: String {
        return "Loop with Reverse"
    }
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutACreator.id.uuid)
        l.name = name
        
        // Blocks
        let b1 = Block("b1", type: .station, center: CGPoint(x: 500, y: 200), rotationAngle: -.pi/2)
        let b2 = Block("b2", type: .free, center: CGPoint(x: 100, y: 200), rotationAngle: .pi/2)
        let b3 = Block("b3", type: .free, center: CGPoint(x: 300, y: 200), rotationAngle: -.pi/4)
        l.add([b1, b2, b3])

        // Feedbacks
        let f11 = Feedback("f11", deviceID: 1, contactID: 1)
        let f12 = Feedback("f12", deviceID: 1, contactID: 2)
        let f21 = Feedback("f21", deviceID: 2, contactID: 1)
        let f22 = Feedback("f22", deviceID: 2, contactID: 2)
        let f31 = Feedback("f31", deviceID: 3, contactID: 1)
        let f32 = Feedback("f32", deviceID: 4, contactID: 2)
        
        l.assign(b1, [f11, f12])
        l.assign(b2, [f21, f22])
        l.assign(b3, [f31, f32])

        // Turnouts
        let t12 = Turnout("t0", type: .singleLeft, address: .init(0, .DCC), center: CGPoint(x: 420, y: 80), rotationAngle: .pi) // b1-b2, b1-b3
        let t21 = Turnout("t1", type: .singleLeft, address: .init(1, .DCC), center: CGPoint(x: 180, y: 320)) // b2-b3, b2-b1
        l.turnouts.append(contentsOf: [t12, t21])
        
        // Transitions
        l.link("0", from: b1.next, to: t12.socket0)
        l.link("1", from: t12.socket1, to: b2.previous)
        l.link("2", from: t12.socket2, to: b3.next)
        l.link("3", from: b2.next, to: t21.socket0)
        l.link("4", from: t21.socket1, to: b1.previous)
        l.link("5", from: t21.socket2, to: b3.previous)

        // Route
        l.newRoute("r1", name: "Station Loop", [Route.Step(b1.id,.next), Route.Step(b2.id, .next), Route.Step(b3.id, .next), Route.Step(b1.id, .previous)])
        l.newRoute("r2", name: "Reverse Loop", [Route.Step(b1, .next), Route.Step(b3, .previous), Route.Step(b2, .previous), Route.Step(b1, .previous)])
        
        // Train
        l.newTrain("1", name: "Rail 2000")
        l.newTrain("2", name: "BLS")

        return l
    }
        
}
