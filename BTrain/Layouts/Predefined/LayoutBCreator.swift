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

// This layout is a 8-style loop used to test out routes
// that can cross each other via the central turnouts.
//   ┌─────────┐                              ┌─────────┐
//┌──│ Block 2 │◀────┐         ┌─────────────▶│ Block 4 │──┐
//│  └─────────┘     │         │              └─────────┘  │
//│                  │         │                           │
//│                  │                                     │
//│                  └─────Turnout12◀───┐                  │
//│                                     │                  │
//│                            ▲        │                  │
//│  ┌─────────┐               │        │     ┌─────────┐  │
//└─▶│ Block 3 │───────────────┘        └─────│ Block 1 │◀─┘
//   └─────────┘                              └─────────┘
final class LayoutBCreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-b")

    var name: String {
        return "8-style Loop"
    }
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutBCreator.id.uuid)
        l.name = name

        // Blocks

        let b_b1 = Block("b1", type: .station, center: CGPoint(x: 380.0, y: 150.0), rotationAngle: -.pi, waitingTime: 10.0)
        let b_b2 = Block("b2", type: .free, center: CGPoint(x: 150.0, y: 50.0), rotationAngle: .pi, waitingTime: 10.0)
        let b_b3 = Block("b3", type: .free, center: CGPoint(x: 150.0, y: 150.0), rotationAngle: 0.0, waitingTime: 10.0)
        let b_b4 = Block("b4", type: .free, center: CGPoint(x: 380.0, y: 50.0), rotationAngle: 0.0, waitingTime: 10.0)
        l.add([b_b1,b_b2,b_b3,b_b4])

        // Feedbacks

        let f_f11 = Feedback("f11", deviceID: 1, contactID: 1)
        let f_f12 = Feedback("f12", deviceID: 1, contactID: 2)
        let f_f21 = Feedback("f21", deviceID: 2, contactID: 1)
        let f_f22 = Feedback("f22", deviceID: 2, contactID: 2)
        let f_f31 = Feedback("f31", deviceID: 3, contactID: 1)
        let f_f32 = Feedback("f32", deviceID: 3, contactID: 2)
        let f_f41 = Feedback("f41", deviceID: 4, contactID: 1)
        let f_f42 = Feedback("f42", deviceID: 4, contactID: 2)
        l.feedbacks.append(contentsOf: [f_f11,f_f12,f_f21,f_f22,f_f31,f_f32,f_f41,f_f42])
        l.assign(b_b1, [f_f11,f_f12])
        l.assign(b_b2, [f_f21,f_f22])
        l.assign(b_b3, [f_f31,f_f32])
        l.assign(b_b4, [f_f41,f_f42])

        // Turnouts

        let t_t1 = Turnout("t1", type: .doubleSlip2, address: .init(0,.MM), address2: .init(0,.MM), state: .straight, center: CGPoint(x: 270.0, y: 100.0), rotationAngle: -2.356194490192345)
        l.turnouts.append(contentsOf: [t_t1])

        // Transitions

        l.link(from: b_b1.next, to: t_t1.socket0)
        l.link(from: t_t1.socket1, to: b_b2.previous)
        l.link(from: b_b2.next, to: b_b3.previous)
        l.link(from: b_b3.next, to: t_t1.socket2)
        l.link(from: t_t1.socket3, to: b_b4.previous)
        l.link(from: b_b4.next, to: b_b1.previous)

        // Routes

        l.newRoute("r1", name: "Loop", [Route.Step(b_b1,.next, nil),Route.Step(b_b2,.next, nil),Route.Step(b_b3,.next, nil),Route.Step(b_b4,.next, nil),Route.Step(b_b1,.next, nil)])

        // Trains
        l.addTrain(.init(uuid: "1", name: "Rail 2000"))
        l.addTrain(.init(uuid: "2", name: "BLS"))

        return l
    }
    
}
