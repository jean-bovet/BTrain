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

//              t3               ┌─────────┐              t4
//     ┌─────▶––––––––––────────▶│ Block 2 │─────────────▶––––––––––───────┐
//     │          \              └─────────┘                   /           │
//     │           ▲                                           │           │
//     │           │                                           │           ▼
//┌─────────┐      │             ┌─────────┐                   │      ┌─────────┐
//│ Block 1 │      └─────────────│ Block 5 │◀──────────────┐   │      │ Block 3 │
//└─────────┘                    └─────────┘               │   │      └─────────┘
//     ▲                                                   │   │           │
//     │                         ┌─────────┐               │   │           │
//     │            ┌────────────│ Block 6 │◀──────────────┼───┘           │
//     │            │            └─────────┘               │               ▼
//     │            ▼                                      │              |
//  t2 |        t8  /            ┌─────────┐           t7  \              |
//     |\  ◀───––––––––––◀───────│ Block 4 │◀─────────––––––––––◀─────── /| t5
//     |                         └─────────┘
//     ▲                                                                   │
//     │                                                                   │
//     │                         ┌─────────┐                               │
//     │            ┌────────────│   S1    │◀───────────┐                  │
//     │            │            └─────────┘            │                  │
//     │            ▼                                   │                  │
//     │           / t1          ┌─────────┐       t6   \                  │
//     └───────── –––– ◀─────────│   S2    │◀──────––––––––––◀─────────────┘
//                               └─────────┘
final class LayoutECreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-e")

    var name: String {
        return "Loop with Alternatives"
    }
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutDCreator.id.uuid)
        l.name = name

        // Blocks

        let b_b1 = Block("b1", type: .free, center: CGPoint(x: 150.0, y: 170.0), rotationAngle: -.pi/2)
        let b_b2 = Block("b2", type: .free, center: CGPoint(x: 380.0, y: 70.0), rotationAngle: 0.0)
        let b_b3 = Block("b3", type: .free, center: CGPoint(x: 630.0, y: 210.0), rotationAngle: .pi/2)
        let b_b4 = Block("b4", type: .free, center: CGPoint(x: 380.0, y: 300.0), rotationAngle: -.pi)
        let b_b5 = Block("b5", type: .free, center: CGPoint(x: 380.0, y: 130.0), rotationAngle: -.pi)
        let b_b6 = Block("b6", type: .free, center: CGPoint(x: 380.0, y: 220.0), rotationAngle: -.pi)
        let b_s1 = Block("s1", type: .station, center: CGPoint(x: 370.0, y: 360.0), rotationAngle: -.pi)
        let b_s2 = Block("s2", type: .station, center: CGPoint(x: 370.0, y: 410.0), rotationAngle: -.pi)
        l.add([b_b1,b_b2,b_b3,b_b4,b_b5,b_b6,b_s1,b_s2])

        // Feedbacks

        let f_fb1 = Feedback("fb1", deviceID: 1, contactID: 1)
        let f_fb2 = Feedback("fb2", deviceID: 1, contactID: 2)
        let f_fb31 = Feedback("fb3.1", deviceID: 1, contactID: 31)
        let f_fb32 = Feedback("fb3.2", deviceID: 1, contactID: 32)
        let f_fb4 = Feedback("fb4", deviceID: 1, contactID: 4)
        let f_fb5 = Feedback("fb5", deviceID: 1, contactID: 5)
        let f_fb6 = Feedback("fb6", deviceID: 1, contactID: 6)
        let f_fs1 = Feedback("fs1", deviceID: 1, contactID: 7)
        let f_fs2 = Feedback("fs2", deviceID: 1, contactID: 8)
        l.feedbacks.append(contentsOf: [f_fb1,f_fb2,f_fb31, f_fb32,f_fb4,f_fb5,f_fb6,f_fs1,f_fs2])
        l.assign(b_b1, [f_fb1])
        l.assign(b_b2, [f_fb2])
        l.assign(b_b3, [f_fb31, f_fb32])
        l.assign(b_b4, [f_fb4])
        l.assign(b_b5, [f_fb5])
        l.assign(b_b6, [f_fb6])
        l.assign(b_s1, [f_fs1])
        l.assign(b_s2, [f_fs2])

        // Turnouts

        let t_t1 = Turnout("t1", type: .singleLeft, address: .init(3, .MM), state: .straight, center: CGPoint(x: 200.0, y: 410.0), rotationAngle: 0.0)
        let t_t2 = Turnout("t2", type: .singleLeft, address: .init(3, .MM), state: .straight, center: CGPoint(x: 150.0, y: 260.0), rotationAngle: .pi/2)
        let t_t3 = Turnout("t3", type: .singleRight, address: .init(3, .MM), state: .straight, center: CGPoint(x: 220.0, y: 70.0), rotationAngle: 0.0)
        let t_t4 = Turnout("t4", type: .singleLeft, address: .init(3, .MM), state: .straight, center: CGPoint(x: 550.0, y: 70.0), rotationAngle: .pi)
        let t_t5 = Turnout("t5", type: .singleRight, address: .init(3, .MM), state: .straight, center: CGPoint(x: 630.0, y: 260.0), rotationAngle: .pi/2)
        let t_t6 = Turnout("t6", type: .singleRight, address: .init(3, .MM), state: .straight, center: CGPoint(x: 570.0, y: 410.0), rotationAngle: .pi)
        let t_t7 = Turnout("t7", type: .singleRight, address: .init(3, .MM), state: .straight, center: CGPoint(x: 520.0, y: 300.0), rotationAngle: .pi)
        let t_t8 = Turnout("t8", type: .singleLeft, address: .init(3, .MM), state: .straight, center: CGPoint(x: 240.0, y: 300.0), rotationAngle: 0.0)
        l.turnouts.append(contentsOf: [t_t1,t_t2,t_t3,t_t4,t_t5,t_t6,t_t7,t_t8])

        // Transitions

        l.link(from: b_s1.next, to: t_t1.socket2)
        l.link(from: t_t1.socket0, to: t_t2.socket1)
        l.link(from: t_t2.socket0, to: b_b1.previous)
        l.link(from: b_b1.next, to: t_t3.socket0)
        l.link(from: t_t3.socket1, to: b_b2.previous)
        l.link(from: b_b2.next, to: t_t4.socket1)
        l.link(from: t_t4.socket0, to: b_b3.previous)
        l.link(from: b_b3.next, to: t_t5.socket0)
        l.link(from: t_t5.socket1, to: t_t6.socket0)
        l.link(from: t_t6.socket2, to: b_s1.previous)
        l.link(from: b_s2.next, to: t_t1.socket1)
        l.link(from: t_t6.socket1, to: b_s2.previous)
        l.link(from: t_t5.socket2, to: t_t7.socket0)
        l.link(from: t_t7.socket1, to: b_b4.previous)
        l.link(from: b_b4.next, to: t_t8.socket1)
        l.link(from: t_t8.socket0, to: t_t2.socket2)
        l.link(from: t_t7.socket2, to: b_b5.previous)
        l.link(from: b_b5.next, to: t_t3.socket2)
        l.link(from: t_t4.socket2, to: b_b6.previous)
        l.link(from: b_b6.next, to: t_t8.socket2)

        // Routes

        l.newRoute("0", name: "Simple Route", [(b_b1,.next),(b_b2,.next)])

        // Trains

        l.newTrain("0", name: "Rail 2000")
        l.newTrain("1", name: "Old Loco")
        
        return l
    }
    
}
