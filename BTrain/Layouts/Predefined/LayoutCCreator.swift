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
        let b1 = Block("b1", type: .station, center: CGPoint(x: 100, y: 200), rotationAngle: -.pi/2)
        let b2 = Block("b2", type: .free, center: CGPoint(x: 300, y: 80))
        let b3 = Block("b3", type: .station, center: CGPoint(x: 500, y: 200), rotationAngle: .pi/2)
        let b4 = Block("b4", type: .free, center: CGPoint(x: 300, y: 320), rotationAngle: .pi)
        let b5 = Block("b5", type: .free, center: CGPoint(x: 300, y: 200), rotationAngle: -.pi*3/4)
        l.add([b1, b2, b3, b4, b5])

        // Feedbacks
        let f11 = Feedback("f11", deviceID: 1, contactID: 1)
        let f12 = Feedback("f12", deviceID: 1, contactID: 2)
        let f21 = Feedback("f21", deviceID: 2, contactID: 1)
        let f22 = Feedback("f22", deviceID: 2, contactID: 2)
        let f31 = Feedback("f31", deviceID: 3, contactID: 1)
        let f32 = Feedback("f32", deviceID: 3, contactID: 2)
        let f41 = Feedback("f41", deviceID: 4, contactID: 1)
        let f42 = Feedback("f42", deviceID: 4, contactID: 2)
        let f51 = Feedback("f51", deviceID: 5, contactID: 1)
        let f52 = Feedback("f52", deviceID: 5, contactID: 2)
        l.feedbacks.append(contentsOf: [f11, f12, f21, f22, f31, f32, f41, f42, f51, f52])
        
        b1.assign([f11.id, f12.id])
        b2.assign([f21.id, f22.id])
        b3.assign([f31.id, f32.id])
        b4.assign([f41.id, f42.id])
        b5.assign([f51.id, f52.id])

        // Turnouts
        let t125 = Turnout("t0", type: .singleRight, address: 3, center: CGPoint(x: 180, y: 80))
        let t345 = Turnout("t1", type: .singleRight, address: 13, center: CGPoint(x: 430, y: 320), rotationAngle: .pi)

        l.turnouts.append(contentsOf: [t125, t345])
        
        // Transitions
        l.link("1", from: b1.next, to: t125.socket0)
        l.link("2", from: t125.socket1, to: b2.previous)
        l.link("3", from: t125.socket2, to: b5.next)

        l.link("4", from: b2.next, to: b3.previous)

        l.link("5", from: b3.next, to: t345.socket0)
        l.link("6", from: t345.socket1, to: b4.previous)
        l.link("7", from: t345.socket2, to: b5.previous)
        
        l.link("8", from: b4.next, to: b1.previous)

        // Route
        l.newRoute("r1", name: "Outer Loop", [(b1, .next), (b2, .next), (b3, .next), (b4, .next), (b1, .next)])
        l.newRoute("r2", name: "Short Route", [(b3, .next), (b4, .next), (b1, .next)])
        l.newRoute("r3", name: "S Route", [(b3, .next), (b5, .next), (b1, .previous)])
        
        // Train
        let t1 = Train(uuid: "1")
        t1.name = "Rail 2000"
        t1.address = 0x4009

        let t2 = Train(uuid: "2")
        t2.name = "Old Loco"
        t2.address = 0x4010

        l.trains.append(contentsOf: [t1, t2])

        return l
    }
    
}
