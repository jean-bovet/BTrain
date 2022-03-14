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

//                            ┌─────────┐
//     ┌───▶   t125   ───────▶│ Block 2 │───────────────────────────┐
//     │                      └─────────┘                           │
//     │         ▲                                                  │
//     │         │                                                  │
//┌─────────┐    │                                                  ▼
//│ Block 1 │    │             ┌─────────┐                     ┌─────────┐
//└─────────┘    └─────────────│ Block 5 │◀──────────────┐     │ Block 3 │
//     ▲                       └─────────┘               │     └─────────┘
//     │                                                 │          │
//     │                                                 │          │
//     │                                                 │          │
//     │                                                 │          │
//     │                       ┌─────────┐                          │
//     └───────────────────────│ Block 4 │◀─────────   t345   ◀─────┘
//                             └─────────┘
final class LayoutCCreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-c")

    var name: String {
        return "Loop and Diagonal"
    }
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutCCreator.id.uuid)
        l.name = name

        // Blocks

        let b_b1 = Block("b1", type: .station, center: CGPoint(x: 60.0, y: 180.0), rotationAngle: -.pi/2, waitingTime: 10.0)
        let b_b2 = Block("b2", type: .free, center: CGPoint(x: 260.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0)
        let b_b3 = Block("b3", type: .station, center: CGPoint(x: 460.0, y: 180.0), rotationAngle: .pi/2, waitingTime: 10.0)
        let b_b4 = Block("b4", type: .free, center: CGPoint(x: 260.0, y: 300.0), rotationAngle: .pi, waitingTime: 10.0)
        let b_b5 = Block("b5", type: .free, center: CGPoint(x: 260.0, y: 180.0), rotationAngle: -2.356194490192345, waitingTime: 10.0)
        l.add([b_b1,b_b2,b_b3,b_b4,b_b5])

        // Feedbacks

        let f_f11 = Feedback("f11", deviceID: 1, contactID: 1)
        let f_f12 = Feedback("f12", deviceID: 1, contactID: 2)
        let f_f21 = Feedback("f21", deviceID: 2, contactID: 1)
        let f_f22 = Feedback("f22", deviceID: 2, contactID: 2)
        let f_f31 = Feedback("f31", deviceID: 3, contactID: 1)
        let f_f32 = Feedback("f32", deviceID: 3, contactID: 2)
        let f_f41 = Feedback("f41", deviceID: 4, contactID: 1)
        let f_f42 = Feedback("f42", deviceID: 4, contactID: 2)
        let f_f51 = Feedback("f51", deviceID: 5, contactID: 1)
        let f_f52 = Feedback("f52", deviceID: 5, contactID: 2)
        l.feedbacks.append(contentsOf: [f_f11,f_f12,f_f21,f_f22,f_f31,f_f32,f_f41,f_f42,f_f51,f_f52])
        l.assign(b_b1, [f_f11,f_f12])
        l.assign(b_b2, [f_f21,f_f22])
        l.assign(b_b3, [f_f31,f_f32])
        l.assign(b_b4, [f_f41,f_f42])
        l.assign(b_b5, [f_f51,f_f52])

        // Turnouts

        let t_t0 = Turnout("t0", type: .singleRight, address: .init(3,.DCC), state: .straight, center: CGPoint(x: 140.0, y: 60.0), rotationAngle: 0.0)
        let t_t1 = Turnout("t1", type: .singleRight, address: .init(13,.DCC), state: .straight, center: CGPoint(x: 390.0, y: 300.0), rotationAngle: .pi)
        l.turnouts.append(contentsOf: [t_t0,t_t1])

        // Transitions

        l.link(from: b_b1.next, to: t_t0.socket0)
        l.link(from: t_t0.socket1, to: b_b2.previous)
        l.link(from: t_t0.socket2, to: b_b5.next)
        l.link(from: b_b2.next, to: b_b3.previous)
        l.link(from: b_b3.next, to: t_t1.socket0)
        l.link(from: t_t1.socket1, to: b_b4.previous)
        l.link(from: t_t1.socket2, to: b_b5.previous)
        l.link(from: b_b4.next, to: b_b1.previous)

        // Routes

        l.newRoute("r1", name: "Outer Loop", [Route.Step(b_b1,.next, nil),Route.Step(b_b2,.next, nil),Route.Step(b_b3,.next, nil),Route.Step(b_b4,.next, nil),Route.Step(b_b1,.next, nil)])
        l.newRoute("r2", name: "Short Route", [Route.Step(b_b3,.next, nil),Route.Step(b_b4,.next, nil),Route.Step(b_b1,.next, nil)])
        l.newRoute("r3", name: "S Route", [Route.Step(b_b3,.next, nil),Route.Step(b_b5,.next, nil),Route.Step(b_b1,.previous, nil)])
        
        // Train
        l.addTrain(Train(uuid: "1", name: "Rail 2000", address: 0x4009))
        l.addTrain(Train(uuid: "2", name: "Old Loco", address: 0x4010))

        return l
    }
    
}
