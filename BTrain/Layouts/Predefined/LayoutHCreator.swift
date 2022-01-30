//
//  LayoutHCreator.swift
//  BTrain
//
//  Created by Jean Bovet on 1/30/22.
//

import Foundation

final class LayoutHCreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-h")

    var name: String {
        return "Layout with Straight Lines"
    }
    
    func newLayout() -> Layout {
        let l = Layout()

        // Blocks

        let b_A = Block("A", type: .sidingPrevious, center: CGPoint(x: 90.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 200.0)
        let b_B = Block("B", type: .free, center: CGPoint(x: 310.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_C = Block("C", type: .free, center: CGPoint(x: 440.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_D = Block("D", type: .free, center: CGPoint(x: 570.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_E = Block("E", type: .sidingNext, center: CGPoint(x: 760.0, y: 60.0), rotationAngle: 0.0, waitingTime: 10.0, length: 200.0)
        let b_B2 = Block("B2", type: .free, center: CGPoint(x: 310.0, y: 150.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        let b_C2 = Block("C2", type: .free, center: CGPoint(x: 440.0, y: 150.0), rotationAngle: -.pi, waitingTime: 10.0, length: 100.0)
        let b_D2 = Block("D2", type: .free, center: CGPoint(x: 570.0, y: 150.0), rotationAngle: 0.0, waitingTime: 10.0, length: 100.0)
        l.add([b_A,b_B,b_C,b_D,b_E,b_B2,b_C2,b_D2])

        // Feedbacks

        let f_A_1 = Feedback("A.1", deviceID: 0, contactID: 0)
        let f_A_2 = Feedback("A.2", deviceID: 0, contactID: 1)
        let f_B_1 = Feedback("B.1", deviceID: 0, contactID: 2)
        let f_B_2 = Feedback("B.2", deviceID: 0, contactID: 3)
        let f_C_1 = Feedback("C.1", deviceID: 0, contactID: 4)
        let f_C_2 = Feedback("C.2", deviceID: 0, contactID: 5)
        let f_D_1 = Feedback("D.1", deviceID: 0, contactID: 6)
        let f_D_2 = Feedback("D.2", deviceID: 0, contactID: 7)
        let f_E_1 = Feedback("E.1", deviceID: 0, contactID: 8)
        let f_E_2 = Feedback("E.2", deviceID: 0, contactID: 9)
        let f_B2_1 = Feedback("B2.1", deviceID: 0, contactID: 10)
        let f_B2_2 = Feedback("B2.2", deviceID: 0, contactID: 11)
        let f_C2_1 = Feedback("C2.1", deviceID: 0, contactID: 12)
        let f_C2_2 = Feedback("C2.2", deviceID: 0, contactID: 13)
        let f_D2_1 = Feedback("D2.1", deviceID: 0, contactID: 14)
        let f_D2_2 = Feedback("D2.2", deviceID: 0, contactID: 15)
        l.feedbacks.append(contentsOf: [f_A_1,f_A_2,f_B_1,f_B_2,f_C_1,f_C_2,f_D_1,f_D_2,f_E_1,f_E_2,f_B2_1,f_B2_2,f_C2_1,f_C2_2,f_D2_1,f_D2_2])
        l.assign(b_A, [f_A_1,f_A_2])
        b_A.entryFeedbackNext = f_A_1.id
        b_A.brakeFeedbackNext = f_A_1.id
        b_A.stopFeedbackNext = f_A_2.id
        b_A.entryFeedbackPrevious = f_A_2.id
        b_A.brakeFeedbackPrevious = f_A_2.id
        b_A.stopFeedbackPrevious = f_A_1.id
        b_A.feedbacks[0].distance = 20.0
        b_A.feedbacks[1].distance = 180.0
        l.assign(b_B, [f_B_1,f_B_2])
        b_B.entryFeedbackNext = f_B_1.id
        b_B.brakeFeedbackNext = f_B_1.id
        b_B.stopFeedbackNext = f_B_2.id
        b_B.entryFeedbackPrevious = f_B_2.id
        b_B.brakeFeedbackPrevious = f_B_2.id
        b_B.stopFeedbackPrevious = f_B_1.id
        b_B.feedbacks[0].distance = 20.0
        b_B.feedbacks[1].distance = 80.0
        l.assign(b_C, [f_C_1,f_C_2])
        b_C.entryFeedbackNext = f_C_1.id
        b_C.brakeFeedbackNext = f_C_1.id
        b_C.stopFeedbackNext = f_C_2.id
        b_C.entryFeedbackPrevious = f_C_2.id
        b_C.brakeFeedbackPrevious = f_C_2.id
        b_C.stopFeedbackPrevious = f_C_1.id
        b_C.feedbacks[0].distance = 20.0
        b_C.feedbacks[1].distance = 80.0
        l.assign(b_D, [f_D_1,f_D_2])
        b_D.entryFeedbackNext = f_D_1.id
        b_D.brakeFeedbackNext = f_D_1.id
        b_D.stopFeedbackNext = f_D_2.id
        b_D.entryFeedbackPrevious = f_D_2.id
        b_D.brakeFeedbackPrevious = f_D_2.id
        b_D.stopFeedbackPrevious = f_D_1.id
        b_D.feedbacks[0].distance = 20.0
        b_D.feedbacks[1].distance = 80.0
        l.assign(b_E, [f_E_1,f_E_2])
        b_E.entryFeedbackNext = f_E_1.id
        b_E.brakeFeedbackNext = f_E_1.id
        b_E.stopFeedbackNext = f_E_2.id
        b_E.entryFeedbackPrevious = f_E_2.id
        b_E.brakeFeedbackPrevious = f_E_2.id
        b_E.stopFeedbackPrevious = f_E_1.id
        b_E.feedbacks[0].distance = 20.0
        b_E.feedbacks[1].distance = 180.0
        l.assign(b_B2, [f_B2_1,f_B2_2])
        b_B2.entryFeedbackNext = f_B2_1.id
        b_B2.brakeFeedbackNext = f_B2_1.id
        b_B2.stopFeedbackNext = f_B2_2.id
        b_B2.entryFeedbackPrevious = f_B2_2.id
        b_B2.brakeFeedbackPrevious = f_B2_2.id
        b_B2.stopFeedbackPrevious = f_B2_1.id
        b_B2.feedbacks[0].distance = 20.0
        b_B2.feedbacks[1].distance = 80.0
        l.assign(b_C2, [f_C2_1,f_C2_2])
        b_C2.entryFeedbackNext = f_C2_1.id
        b_C2.brakeFeedbackNext = f_C2_1.id
        b_C2.stopFeedbackNext = f_C2_2.id
        b_C2.entryFeedbackPrevious = f_C2_2.id
        b_C2.brakeFeedbackPrevious = f_C2_2.id
        b_C2.stopFeedbackPrevious = f_C2_1.id
        b_C2.feedbacks[0].distance = 20.0
        b_C2.feedbacks[1].distance = 80.0
        l.assign(b_D2, [f_D2_1,f_D2_2])
        b_D2.entryFeedbackNext = f_D2_1.id
        b_D2.brakeFeedbackNext = f_D2_1.id
        b_D2.stopFeedbackNext = f_D2_2.id
        b_D2.entryFeedbackPrevious = f_D2_2.id
        b_D2.brakeFeedbackPrevious = f_D2_2.id
        b_D2.stopFeedbackPrevious = f_D2_1.id
        b_D2.feedbacks[0].distance = 20.0
        b_D2.feedbacks[1].distance = 80.0

        // Turnouts

        let t_AB = Turnout("AB", type: .singleRight, address: .init(0,.MM), state: .straight, center: CGPoint(x: 200.0, y: 60.0), rotationAngle: 0.0, length: 10.0)
        let t_DE = Turnout("DE", type: .singleLeft, address: .init(1,.MM), state: .straight, center: CGPoint(x: 670.0, y: 60.0), rotationAngle: -.pi, length: 10.0)
        l.turnouts.append(contentsOf: [t_AB,t_DE])

        // Transitions

        l.link(from: t_AB.socket0, to: b_A.next)
        l.link(from: t_AB.socket2, to: b_B2.previous)
        l.link(from: t_AB.socket1, to: b_B.previous)
        l.link(from: b_B.next, to: b_C.previous)
        l.link(from: b_C.next, to: b_D.previous)
        l.link(from: b_D.next, to: t_DE.socket1)
        l.link(from: t_DE.socket2, to: b_D2.next)
        l.link(from: t_DE.socket0, to: b_E.previous)
        l.link(from: b_B2.next, to: b_C2.next)
        l.link(from: b_C2.previous, to: b_D2.previous)

        // Routes

        l.newRoute("0", name: "A-E", [Route.Step(b_A,.next, nil),Route.Step(b_B,.next, nil),Route.Step(b_C,.next, nil),Route.Step(b_D,.next, nil),Route.Step(b_E,.next, nil)])
        l.newRoute("1", name: "A-B2-C2-D2-E", [Route.Step(b_A,.next, nil),Route.Step(b_B2,.next, nil),Route.Step(b_C2,.previous, nil),Route.Step(b_D2,.next, nil),Route.Step(b_E,.next, nil)])

        // Trains

        l.addTrain(Train(uuid: "0", name: "IC", address: 0x0000, decoder: .MFX, length: 120.0, magnetDistance: 1.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        
        return l
    }
}
