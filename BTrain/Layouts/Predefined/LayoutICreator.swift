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

//    ┌─────────┐                      ┌─────────┐             ┌─────────┐
//    │   s1    │───▶  t1  ───▶  t2  ─▶│   b1    │─▶  t4  ────▶│   s2    │
//    └─────────┘                      └─────────┘             └─────────┘
//         ▲            │         │                    ▲            │
//         │            │         │                    │            │
//         │            ▼         ▼                    │            │
//         │       ┌─────────┐                    ┌─────────┐       │
//         │       │   b2    │─▶ t3  ────────────▶│   b3    │       │
//         │       └─────────┘                    └─────────┘       ▼
//    ┌─────────┐                                              ┌─────────┐
//    │   b5    │◀─────────────────────────────────────────────│   b4    │
//    └─────────┘                                              └─────────┘
final class LayoutICreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-i")

    var name: String {
        return "Layout with Alternate Lines"
    }
    
    func newLayout() -> Layout {
        let l = Layout()

        // Blocks

        let b_s1 = Block("s1", type: .station, center: CGPoint(x: 140.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_s2 = Block("s2", type: .station, center: CGPoint(x: 760.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_b1 = Block("b1", type: .free, center: CGPoint(x: 490.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_b2 = Block("b2", type: .free, center: CGPoint(x: 360.0, y: 130.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_b3 = Block("b3", type: .free, center: CGPoint(x: 540.0, y: 130.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_b4 = Block("b4", type: .free, center: CGPoint(x: 760.0, y: 220.0), rotationAngle: .pi, waitingTime: 10.0, length: 100.0)
        let b_b5 = Block("b5", type: .free, center: CGPoint(x: 150.0, y: 220.0), rotationAngle: -.pi, waitingTime: 10.0, length: 100.0)
        l.add([b_s1,b_s2,b_b1,b_b2,b_b3,b_b4,b_b5])

        // Feedbacks

        let f_f1_1 = Feedback("f1.1", deviceID: 0, contactID: 0)
        let f_f1_2 = Feedback("f1.2", deviceID: 0, contactID: 1)
        let f_f2_1 = Feedback("f2.1", deviceID: 0, contactID: 2)
        let f_f2_2 = Feedback("f2.2", deviceID: 0, contactID: 3)
        let f_f3_1 = Feedback("f3.1", deviceID: 0, contactID: 4)
        let f_f3_2 = Feedback("f3.2", deviceID: 0, contactID: 5)
        let f_f4_1 = Feedback("f4.1", deviceID: 0, contactID: 6)
        let f_f4_2 = Feedback("f4.2", deviceID: 0, contactID: 7)
        let f_f5_1 = Feedback("f5.1", deviceID: 0, contactID: 8)
        let f_f5_2 = Feedback("f5.2", deviceID: 0, contactID: 9)
        let f_fs1_1 = Feedback("fs1.1", deviceID: 0, contactID: 10)
        let f_fs1_2 = Feedback("fs1.2", deviceID: 0, contactID: 11)
        let f_fs2_1 = Feedback("fs2.1", deviceID: 0, contactID: 12)
        let f_fs2_2 = Feedback("fs2.2", deviceID: 0, contactID: 13)
        l.feedbacks.append(contentsOf: [f_f1_1,f_f1_2,f_f2_1,f_f2_2,f_f3_1,f_f3_2,f_f4_1,f_f4_2,f_f5_1,f_f5_2,f_fs1_1,f_fs1_2,f_fs2_1,f_fs2_2])
        l.assign(b_s1, [f_fs1_1,f_fs1_2])
        b_s1.entryFeedbackNext = f_fs1_1.id
        b_s1.brakeFeedbackNext = f_fs1_1.id
        b_s1.stopFeedbackNext = f_fs1_2.id
        b_s1.entryFeedbackPrevious = f_fs1_2.id
        b_s1.brakeFeedbackPrevious = f_fs1_2.id
        b_s1.stopFeedbackPrevious = f_fs1_1.id
        b_s1.feedbacks[0].distance = 20.0
        b_s1.feedbacks[1].distance = 80.0
        l.assign(b_s2, [f_fs2_1,f_fs2_2])
        b_s2.entryFeedbackNext = f_fs2_1.id
        b_s2.brakeFeedbackNext = f_fs2_1.id
        b_s2.stopFeedbackNext = f_fs2_2.id
        b_s2.entryFeedbackPrevious = f_fs2_2.id
        b_s2.brakeFeedbackPrevious = f_fs2_2.id
        b_s2.stopFeedbackPrevious = f_fs2_1.id
        b_s2.feedbacks[0].distance = 20.0
        b_s2.feedbacks[1].distance = 80.0
        l.assign(b_b1, [f_f1_1,f_f1_2])
        b_b1.feedbacks[0].distance = 20.0
        b_b1.feedbacks[1].distance = 80.0
        l.assign(b_b2, [f_f2_1,f_f2_2])
        b_b2.feedbacks[0].distance = 20.0
        b_b2.feedbacks[1].distance = 80.0
        l.assign(b_b3, [f_f3_1,f_f3_2])
        b_b3.feedbacks[0].distance = 20.0
        b_b3.feedbacks[1].distance = 80.0
        l.assign(b_b4, [f_f4_1,f_f4_2])
        b_b4.feedbacks[0].distance = 20.0
        b_b4.feedbacks[1].distance = 80.0
        l.assign(b_b5, [f_f5_1,f_f5_2])
        b_b5.feedbacks[0].distance = 20.0
        b_b5.feedbacks[1].distance = 80.0

        // Turnouts

        let t_t1 = Turnout("t1", type: .singleRight, address: .init(0,.MM), state: .straight, center: CGPoint(x: 220.0, y: 60.0), rotationAngle: 0.0, length: 15.0)
        let t_t2 = Turnout("t2", type: .singleRight, address: .init(1,.MM), state: .straight, center: CGPoint(x: 380.0, y: 60.0), rotationAngle: 0.0, length: 15.0)
        let t_t3 = Turnout("t3", type: .singleRight, address: .init(2,.MM), state: .straight, center: CGPoint(x: 450.0, y: 130.0), rotationAngle: -.pi, length: 15.0)
        let t_t4 = Turnout("t4", type: .singleLeft, address: .init(3,.MM), state: .straight, center: CGPoint(x: 670.0, y: 60.0), rotationAngle: -.pi, length: 15.0)
        l.turnouts.append(contentsOf: [t_t1,t_t2,t_t3,t_t4])

        // Transitions

        l.link(from: b_s1.next, to: t_t1.socket0)
        l.link(from: t_t1.socket2, to: b_b2.previous)
        l.link(from: t_t1.socket1, to: t_t2.socket0)
        l.link(from: t_t2.socket2, to: t_t3.socket2)
        l.link(from: b_b2.next, to: t_t3.socket1)
        l.link(from: t_t3.socket0, to: b_b3.previous)
        l.link(from: t_t2.socket1, to: b_b1.previous)
        l.link(from: b_b1.next, to: t_t4.socket1)
        l.link(from: t_t4.socket2, to: b_b3.next)
        l.link(from: t_t4.socket0, to: b_s2.previous)
        l.link(from: b_s2.next, to: b_b4.previous)
        l.link(from: b_b4.next, to: b_b5.previous)
        l.link(from: b_b5.next, to: b_s1.previous)

        // Routes


        // Trains

        l.addTrain(Train(uuid: "0", name: "460 106-8 SBB", address: 0x0006, decoder: .MFX, length: 20.0, magnetDistance: 1.0, maxSpeed: 230, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "1", name: "474 003-1 SBBC", address: 0x0015, decoder: .MFX, length: 20.0, magnetDistance: 1.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        return l
    }
}
