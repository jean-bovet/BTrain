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

final class LayoutFCreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-f")

    var name: String {
        return "Complex Layout"
    }
    
    func newLayout() -> Layout {
        let l = Layout(uuid: LayoutFCreator.id.uuid)
        l.name = name

        // Blocks

        let b_A = Block("A", type: .sidingNext, center: CGPoint(x: 235.0, y: 750.0), rotationAngle: -.pi, waitingTime: 10.0, length: 45.0)
        let b_B = Block("B", type: .sidingNext, center: CGPoint(x: 235.0, y: 810.0), rotationAngle: -.pi, waitingTime: 10.0, length: 56.0)
        let b_C = Block("C", type: .sidingPrevious, center: CGPoint(x: 755.0, y: 810.0), rotationAngle: -.pi, waitingTime: 10.0, length: 54.0)
        let b_HL1 = Block("HL1", type: .free, center: CGPoint(x: 155.0, y: 230.0), rotationAngle: .pi/2, waitingTime: 10.0, length: 100.0)
        let b_HL2 = Block("HL2", type: .free, center: CGPoint(x: 635.0, y: 240.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 250.0)
        let b_HLS_P1 = Block("HLS_P1", type: .station, center: CGPoint(x: 350.0, y: 260.0), rotationAngle: 6.283185307179586, waitingTime: 10.0, length: 145.0)
        let b_HLS_P2 = Block("HLS_P2", type: .station, center: CGPoint(x: 370.0, y: 320.0), rotationAngle: 0.0, waitingTime: 10.0, length: 145.0)
        let b_HS1 = Block("HS1", type: .sidingPrevious, center: CGPoint(x: 450.0, y: 370.0), rotationAngle: .pi, waitingTime: 10.0, length: 100.0)
        let b_HS2 = Block("HS2", type: .sidingPrevious, center: CGPoint(x: 375.0, y: 410.0), rotationAngle: .pi, waitingTime: 10.0, length: 100.0)
        let b_IL1 = Block("IL1", type: .free, center: CGPoint(x: 105.0, y: 250.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 125.0)
        let b_IL2 = Block("IL2", type: .free, center: CGPoint(x: 410.0, y: 120.0), rotationAngle: 0.0, waitingTime: 10.0, length: 70.0)
        let b_IL3 = Block("IL3", type: .free, center: CGPoint(x: 705.0, y: 260.0), rotationAngle: .pi/2, waitingTime: 10.0, length: 223.0)
        let b_IL4 = Block("IL4", type: .free, center: CGPoint(x: 425.0, y: 460.0), rotationAngle: .pi, waitingTime: 10.0, length: 160.0)
        let b_LCF1 = Block("LCF1", type: .station, center: CGPoint(x: 985.0, y: 300.0), rotationAngle: .pi/2, waitingTime: 10.0, length: 121.0)
        let b_LCF2 = Block("LCF2", type: .station, center: CGPoint(x: 1065.0, y: 300.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 123.0)
        let b_M1 = Block("M1", type: .free, center: CGPoint(x: 855.0, y: 530.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 460.0)
        let b_M2D = Block("M2D", type: .free, center: CGPoint(x: 905.0, y: 290.0), rotationAngle: .pi/2, waitingTime: 10.0, length: 89.0)
        let b_M2U = Block("M2U", type: .free, center: CGPoint(x: 855.0, y: 290.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 89.0)
        let b_M3 = Block("M3", type: .free, center: CGPoint(x: 1155.0, y: 300.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 320.0)
        let b_NE1 = Block("NE1", type: .station, center: CGPoint(x: 465.0, y: 570.0), rotationAngle: .pi, waitingTime: 10.0, length: 220.0)
        let b_NE2 = Block("NE2", type: .station, center: CGPoint(x: 465.0, y: 630.0), rotationAngle: .pi, waitingTime: 10.0, length: 200.0)
        let b_NE3 = Block("NE3", type: .station, center: CGPoint(x: 465.0, y: 690.0), rotationAngle: .pi, waitingTime: 10.0, length: 140.0)
        let b_NE4 = Block("NE4", type: .station, center: CGPoint(x: 465.0, y: 750.0), rotationAngle: .pi, waitingTime: 10.0, length: 138.0)
        let b_NE5 = Block("NE5", type: .station, center: CGPoint(x: 465.0, y: 810.0), rotationAngle: .pi, waitingTime: 10.0, length: 107.0)
        let b_OL1 = Block("OL1", type: .free, center: CGPoint(x: 55.0, y: 250.0), rotationAngle: -.pi/2, waitingTime: 10.0, length: 190.0)
        let b_OL2 = Block("OL2", type: .free, center: CGPoint(x: 420.0, y: 50.0), rotationAngle: 0.0, waitingTime: 10.0, length: 112.0)
        let b_OL3 = Block("OL3", type: .free, center: CGPoint(x: 765.0, y: 260.0), rotationAngle: .pi/2, waitingTime: 10.0, length: 120.0)
        let b_OL4 = Block("OL4", type: .free, center: CGPoint(x: 425.0, y: 510.0), rotationAngle: .pi, waitingTime: 10.0, length: 300.0)
        let b_S = Block("S", type: .free, center: CGPoint(x: 415.0, y: 190.0), rotationAngle: -.pi, waitingTime: 10.0, length: 90.0)
        l.add([b_A,b_B,b_C,b_HL1,b_HL2,b_HLS_P1,b_HLS_P2,b_HS1,b_HS2,b_IL1,b_IL2,b_IL3,b_IL4,b_LCF1,b_LCF2,b_M1,b_M2D,b_M2U,b_M3,b_NE1,b_NE2,b_NE3,b_NE4,b_NE5,b_OL1,b_OL2,b_OL3,b_OL4,b_S])

        // Feedbacks

        let f_NE3_1 = Feedback("NE3.1", deviceID: 1, contactID: 2012)
        let f_NE3_2 = Feedback("NE3.2", deviceID: 1, contactID: 8)
        let f_NE4_1 = Feedback("NE4.1", deviceID: 1, contactID: 2013)
        let f_NE4_2 = Feedback("NE4.2", deviceID: 1, contactID: 2010)
        let f_NE5_1 = Feedback("NE5.1", deviceID: 1, contactID: 2014)
        let f_NE5_2 = Feedback("NE5.2", deviceID: 1, contactID: 2011)
        let f_HS1 = Feedback("HS1", deviceID: 1, contactID: 3)
        let f_HS2 = Feedback("HS2", deviceID: 1, contactID: 15)
        let f_HL1_1 = Feedback("HL1.1", deviceID: 1, contactID: 1)
        let f_HL1_2 = Feedback("HL1.2", deviceID: 1, contactID: 4)
        let f_HL2_1 = Feedback("HL2.1", deviceID: 1, contactID: 2021)
        let f_HL2_2 = Feedback("HL2.2", deviceID: 1, contactID: 2004)
        let f_HLSP1_1 = Feedback("HLSP1.1", deviceID: 1, contactID: 9)
        let f_HLSP1_2 = Feedback("HLSP1.2", deviceID: 1, contactID: 2005)
        let f_HLSP2_1 = Feedback("HLSP2.1", deviceID: 1, contactID: 10)
        let f_HLSP2_2 = Feedback("HLSP2.2", deviceID: 1, contactID: 2003)
        let f_A = Feedback("A", deviceID: 2, contactID: 1)
        let f_B = Feedback("B", deviceID: 1, contactID: 1002)
        let f_C = Feedback("C", deviceID: 2, contactID: 2)
        let f_M2U = Feedback("M2U", deviceID: 1, contactID: 2016)
        let f_M2D = Feedback("M2D", deviceID: 1, contactID: 1001)
        let f_MS1_1 = Feedback("MS1.1", deviceID: 1, contactID: 2028)
        let f_MS1_2 = Feedback("MS1.2", deviceID: 1, contactID: 2030)
        let f_MS2_1 = Feedback("MS2.1", deviceID: 2, contactID: 3)
        let f_MS2_2 = Feedback("MS2.2", deviceID: 2, contactID: 4)
        let f_M3_1 = Feedback("M3.1", deviceID: 1, contactID: 2031)
        let f_M3_2 = Feedback("M3.2", deviceID: 1, contactID: 2032)
        let f_IL1_1 = Feedback("IL1.1", deviceID: 1, contactID: 6)
        let f_IL1_2 = Feedback("IL1.2", deviceID: 1, contactID: 7)
        let f_IL2_1 = Feedback("IL2.1", deviceID: 1, contactID: 2027)
        let f_IL2_2 = Feedback("IL2.2", deviceID: 1, contactID: 2007)
        let f_IL2_3 = Feedback("IL2.3", deviceID: 1, contactID: 2029)
        let f_IL3_1 = Feedback("IL3.1", deviceID: 1, contactID: 2022)
        let f_IL3_2 = Feedback("IL3.2", deviceID: 1, contactID: 2024)
        let f_IL4_1 = Feedback("IL4.1", deviceID: 1, contactID: 2001)
        let f_IL4_2 = Feedback("IL4.2", deviceID: 1, contactID: 14)
        let f_S_1 = Feedback("S.1", deviceID: 1, contactID: 2002)
        let f_S_2 = Feedback("S.2", deviceID: 1, contactID: 2008)
        let f_OL1_1 = Feedback("OL1.1", deviceID: 1, contactID: 5)
        let f_OL1_2 = Feedback("OL1.2", deviceID: 1, contactID: 2)
        let f_OL2_1 = Feedback("OL2.1", deviceID: 1, contactID: 2009)
        let f_OL2_2 = Feedback("OL2.2", deviceID: 1, contactID: 2006)
        let f_OL3_1 = Feedback("OL3.1", deviceID: 1, contactID: 2023)
        let f_OL3_2 = Feedback("OL3.2", deviceID: 1, contactID: 2020)
        let f_OL4_1 = Feedback("OL4.1", deviceID: 1, contactID: 2017)
        let f_OL4_2 = Feedback("OL4.2", deviceID: 1, contactID: 2015)
        let f_OL4_3 = Feedback("OL4.3", deviceID: 1, contactID: 16)
        let f_NE1_1 = Feedback("NE1.1", deviceID: 1, contactID: 2018)
        let f_NE1_2 = Feedback("NE1.2", deviceID: 1, contactID: 13)
        let f_NE2_1 = Feedback("NE2.1", deviceID: 1, contactID: 2019)
        let f_NE2_2 = Feedback("NE2.2", deviceID: 1, contactID: 12)
        let f_M1_1 = Feedback("M1.1", deviceID: 1, contactID: 2025)
        let f_M1_2 = Feedback("M1.2", deviceID: 1, contactID: 2026)
        let f_M1_3 = Feedback("M1.3", deviceID: 1, contactID: 11)
        l.feedbacks.append(contentsOf: [f_NE3_1,f_NE3_2,f_NE4_1,f_NE4_2,f_NE5_1,f_NE5_2,f_HS1,f_HS2,f_HL1_1,f_HL1_2,f_HL2_1,f_HL2_2,f_HLSP1_1,f_HLSP1_2,f_HLSP2_1,f_HLSP2_2,f_A,f_B,f_C,f_M2U,f_M2D,f_MS1_1,f_MS1_2,f_MS2_1,f_MS2_2,f_M3_1,f_M3_2,f_IL1_1,f_IL1_2,f_IL2_1,f_IL2_2,f_IL2_3,f_IL3_1,f_IL3_2,f_IL4_1,f_IL4_2,f_S_1,f_S_2,f_OL1_1,f_OL1_2,f_OL2_1,f_OL2_2,f_OL3_1,f_OL3_2,f_OL4_1,f_OL4_2,f_OL4_3,f_NE1_1,f_NE1_2,f_NE2_1,f_NE2_2,f_M1_1,f_M1_2,f_M1_3])
        l.assign(b_A, [f_A])
        b_A.feedbacks[0].distance = 0.0
        l.assign(b_B, [f_B])
        b_B.feedbacks[0].distance = 0.0
        l.assign(b_C, [f_C])
        b_C.feedbacks[0].distance = 0.0
        l.assign(b_HL1, [f_HL1_1,f_HL1_2])
        b_HL1.feedbacks[0].distance = 30.0
        b_HL1.feedbacks[1].distance = 80.0
        l.assign(b_HL2, [f_HL2_1,f_HL2_2])
        b_HL2.feedbacks[0].distance = 30.0
        b_HL2.feedbacks[1].distance = 220.0
        l.assign(b_HLS_P1, [f_HLSP1_1,f_HLSP1_2])
        b_HLS_P1.feedbacks[0].distance = 30.0
        b_HLS_P1.feedbacks[1].distance = 70.0
        l.assign(b_HLS_P2, [f_HLSP2_1,f_HLSP2_2])
        b_HLS_P2.feedbacks[0].distance = 30.0
        b_HLS_P2.feedbacks[1].distance = 115.0
        l.assign(b_HS1, [f_HS1])
        b_HS1.feedbacks[0].distance = 30.0
        l.assign(b_HS2, [f_HS2])
        b_HS2.feedbacks[0].distance = 8.0
        l.assign(b_IL1, [f_IL1_1,f_IL1_2])
        b_IL1.feedbacks[0].distance = 10.0
        b_IL1.feedbacks[1].distance = 90.0
        l.assign(b_IL2, [f_IL2_1,f_IL2_2,f_IL2_3])
        b_IL2.brakeFeedbackNext = f_IL2_1.id
        b_IL2.stopFeedbackNext = f_IL2_2.id
        b_IL2.brakeFeedbackPrevious = f_IL2_3.id
        b_IL2.stopFeedbackPrevious = f_IL2_2.id
        b_IL2.feedbacks[0].distance = 5.0
        b_IL2.feedbacks[1].distance = 40.0
        b_IL2.feedbacks[2].distance = 65.0
        l.assign(b_IL3, [f_IL3_1,f_IL3_2])
        b_IL3.feedbacks[0].distance = 30.0
        b_IL3.feedbacks[1].distance = 193.0
        l.assign(b_IL4, [f_IL4_1,f_IL4_2])
        b_IL4.feedbacks[0].distance = 30.0
        b_IL4.feedbacks[1].distance = 130.0
        l.assign(b_LCF1, [f_MS1_1,f_MS1_2])
        b_LCF1.feedbacks[0].distance = 30.0
        b_LCF1.feedbacks[1].distance = 93.0
        l.assign(b_LCF2, [f_MS2_1,f_MS2_2])
        b_LCF2.feedbacks[0].distance = 30.0
        b_LCF2.feedbacks[1].distance = 93.0
        l.assign(b_M1, [f_M1_1,f_M1_2,f_M1_3])
        b_M1.feedbacks[0].distance = 30.0
        b_M1.feedbacks[1].distance = 230.0
        b_M1.feedbacks[2].distance = 430.0
        l.assign(b_M2D, [f_M2D])
        b_M2D.feedbacks[0].distance = 30.0
        l.assign(b_M2U, [f_M2U])
        b_M2U.feedbacks[0].distance = 30.0
        l.assign(b_M3, [f_M3_1,f_M3_2])
        b_M3.feedbacks[0].distance = 30.0
        b_M3.feedbacks[1].distance = 290.0
        l.assign(b_NE1, [f_NE1_1,f_NE1_2])
        b_NE1.feedbacks[0].distance = 36.0
        b_NE1.feedbacks[1].distance = 156.0
        l.assign(b_NE2, [f_NE2_1,f_NE2_2])
        b_NE2.feedbacks[0].distance = 30.0
        b_NE2.feedbacks[1].distance = 170.0
        l.assign(b_NE3, [f_NE3_1,f_NE3_2])
        b_NE3.feedbacks[0].distance = 30.0
        b_NE3.feedbacks[1].distance = 111.0
        l.assign(b_NE4, [f_NE4_1,f_NE4_2])
        b_NE4.feedbacks[0].distance = 30.0
        b_NE4.feedbacks[1].distance = 108.0
        l.assign(b_NE5, [f_NE5_1,f_NE5_2])
        b_NE5.feedbacks[0].distance = 30.0
        b_NE5.feedbacks[1].distance = 77.0
        l.assign(b_OL1, [f_OL1_1,f_OL1_2])
        b_OL1.feedbacks[0].distance = 30.0
        b_OL1.feedbacks[1].distance = 160.0
        l.assign(b_OL2, [f_OL2_1,f_OL2_2])
        b_OL2.feedbacks[0].distance = 30.0
        b_OL2.feedbacks[1].distance = 82.0
        l.assign(b_OL3, [f_OL3_1,f_OL3_2])
        b_OL3.feedbacks[0].distance = 30.0
        b_OL3.feedbacks[1].distance = 90.0
        l.assign(b_OL4, [f_OL4_1,f_OL4_2,f_OL4_3])
        b_OL4.feedbacks[0].distance = 30.0
        b_OL4.feedbacks[1].distance = 150.0
        b_OL4.feedbacks[2].distance = 270.0
        l.assign(b_S, [f_S_1,f_S_2])
        b_S.feedbacks[0].distance = 30.0
        b_S.feedbacks[1].distance = 60.0

        // Turnouts

        let t_A_1 = Turnout("A.1", type: .singleLeft, address: .init(1,.DCC), state: .straight, center: CGPoint(x: 205.0, y: 630.0), rotationAngle: .pi/4, length: 20.0)
        let t_A_2 = Turnout("A.2", type: .singleRight, address: .init(36,.MM), state: .branchRight, center: CGPoint(x: 165.0, y: 460.0), rotationAngle: 0.0, length: 20.0)
        let t_A_34 = Turnout("A.34", type: .doubleSlip2, address: .init(3,.DCC), address2: .init(4,.DCC), state: .straight01, center: CGPoint(x: 125.0, y: 510.0), rotationAngle: 0.0, length: 20.0)
        let t_B_1 = Turnout("B.1", type: .singleRight, address: .init(5,.DCC), state: .branchRight, center: CGPoint(x: 395.0, y: 810.0), rotationAngle: -.pi, length: 18.0)
        let t_B_2 = Turnout("B.2", type: .doubleSlip, address: .init(6,.DCC), state: .branch, center: CGPoint(x: 335.0, y: 750.0), rotationAngle: 0.0, length: 18.0)
        let t_B_3 = Turnout("B.3", type: .singleRight, address: .init(7,.DCC), state: .branchRight, center: CGPoint(x: 275.0, y: 690.0), rotationAngle: 0.0, length: 18.0)
        let t_B_4 = Turnout("B.4", type: .singleLeft, address: .init(8,.DCC), state: .branchLeft, center: CGPoint(x: 295.0, y: 630.0), rotationAngle: 0.0, length: 15.0)
        let t_C_1 = Turnout("C.1", type: .threeWay, address: .init(9,.DCC), address2: .init(10,.DCC), state: .branchRight, center: CGPoint(x: 665.0, y: 750.0), rotationAngle: -.pi, length: 18.0)
        let t_C_3 = Turnout("C.3", type: .singleRight, address: .init(11,.DCC), state: .branchRight, center: CGPoint(x: 605.0, y: 690.0), rotationAngle: 0.0, length: 18.0)
        let t_C_4 = Turnout("C.4", type: .singleLeft, address: .init(12,.DCC), state: .branchLeft, center: CGPoint(x: 605.0, y: 810.0), rotationAngle: 0.0, length: 18.0)
        let t_D_1 = Turnout("D.1", type: .singleRight, address: .init(13,.DCC), state: .branchRight, center: CGPoint(x: 105.0, y: 50.0), rotationAngle: 0.0, length: 20.0)
        let t_D_2 = Turnout("D.2", type: .doubleSlip2, address: .init(14,.DCC), address2: .init(15,.DCC), state: .straight01, center: CGPoint(x: 255.0, y: 120.0), rotationAngle: 0.0, length: 20.0)
        let t_D_4 = Turnout("D.4", type: .singleLeft, address: .init(16,.DCC), state: .straight, center: CGPoint(x: 205.0, y: 460.0), rotationAngle: 0.0, length: 20.0)
        let t_E_1 = Turnout("E.1", type: .singleLeft, address: .init(17,.DCC), state: .branchLeft, center: CGPoint(x: 705.0, y: 50.0), rotationAngle: .pi, length: 20.0)
        let t_E_2 = Turnout("E.2", type: .singleLeft, address: .init(18,.DCC), state: .branchLeft, center: CGPoint(x: 645.0, y: 120.0), rotationAngle: .pi, length: 20.0)
        let t_E_3 = Turnout("E.3", type: .singleLeft, address: .init(19,.DCC), state: .branchLeft, center: CGPoint(x: 575.0, y: 120.0), rotationAngle: 0.0, length: 20.0)
        let t_E_4 = Turnout("E.4", type: .singleRight, address: .init(20,.DCC), state: .straight, center: CGPoint(x: 615.0, y: 630.0), rotationAngle: .pi, length: 20.0)
        let t_F_1 = Turnout("F.1", type: .singleRight, address: .init(25,.DCC), state: .branchRight, center: CGPoint(x: 765.0, y: 560.0), rotationAngle: .pi/2, length: 20.0)
        let t_F_2 = Turnout("F.2", type: .singleRight, address: .init(26,.DCC), state: .straight, center: CGPoint(x: 765.0, y: 620.0), rotationAngle: .pi/2, length: 20.0)
        let t_F_3 = Turnout("F.3", type: .singleRight, address: .init(27,.DCC), state: .straight, center: CGPoint(x: 765.0, y: 470.0), rotationAngle: .pi/2, length: 20.0)
        let t_F_4 = Turnout("F.4", type: .singleRight, address: .init(28,.DCC), state: .branchRight, center: CGPoint(x: 655.0, y: 460.0), rotationAngle: .pi, length: 18.0)
        let t_H_1 = Turnout("H.1", type: .singleLeft, address: .init(29,.MM), state: .branchLeft, center: CGPoint(x: 195.0, y: 120.0), rotationAngle: -.pi, length: 20.0)
        let t_H_2 = Turnout("H.2", type: .singleLeft, address: .init(30,.MM), state: .branchLeft, center: CGPoint(x: 225.0, y: 320.0), rotationAngle: 0.0, length: 15.0)
        let t_H_3 = Turnout("H.3", type: .singleLeft, address: .init(31,.MM), state: .straight, center: CGPoint(x: 505.0, y: 260.0), rotationAngle: .pi, length: 15.0)
        let t_H_4 = Turnout("H.4", type: .singleLeft, address: .init(32,.MM), state: .straight, center: CGPoint(x: 285.0, y: 410.0), rotationAngle: 0.0, length: 15.0)
        let t_M_1 = Turnout("M.1", type: .singleLeft, address: .init(2,.DCC), state: .straight, center: CGPoint(x: 725.0, y: 750.0), rotationAngle: 0.0, length: 10.0)
        let t_Z_1 = Turnout("Z.1", type: .singleRight, address: .init(35,.MM), state: .straight, center: CGPoint(x: 855.0, y: 400.0), rotationAngle: -.pi/2, length: 15.0)
        let t_Z_2 = Turnout("Z.2", type: .singleLeft, address: .init(34,.MM), state: .straight, center: CGPoint(x: 855.0, y: 160.0), rotationAngle: .pi/2, length: 15.0)
        let t_Z_3 = Turnout("Z.3", type: .singleRight, address: .init(40,.MM), state: .straight, center: CGPoint(x: 1005.0, y: 100.0), rotationAngle: 0.0, length: 15.0)
        let t_Z_4 = Turnout("Z.4", type: .singleLeft, address: .init(33,.MM), state: .branchLeft, center: CGPoint(x: 955.0, y: 100.0), rotationAngle: .pi/4, length: 15.0)
        let t_Z_5 = Turnout("Z.5", type: .singleRight, address: .init(39,.MM), state: .straight, center: CGPoint(x: 985.0, y: 450.0), rotationAngle: -.pi/2, length: 15.0)
        l.turnouts.append(contentsOf: [t_A_1,t_A_2,t_A_34,t_B_1,t_B_2,t_B_3,t_B_4,t_C_1,t_C_3,t_C_4,t_D_1,t_D_2,t_D_4,t_E_1,t_E_2,t_E_3,t_E_4,t_F_1,t_F_2,t_F_3,t_F_4,t_H_1,t_H_2,t_H_3,t_H_4,t_M_1,t_Z_1,t_Z_2,t_Z_3,t_Z_4,t_Z_5])

        // Transitions

        l.link(from: t_D_2.socket1, to: b_IL2.previous)
        l.link(from: t_D_2.socket3, to: b_S.next)
        l.link(from: b_IL2.next, to: t_E_3.socket0)
        l.link(from: t_E_3.socket2, to: t_E_1.socket2)
        l.link(from: b_IL3.next, to: t_F_4.socket0)
        l.link(from: t_F_4.socket1, to: b_IL4.previous)
        l.link(from: t_F_4.socket2, to: b_S.previous)
        l.link(from: t_A_2.socket0, to: b_IL1.previous)
        l.link(from: t_A_2.socket2, to: t_A_34.socket2)
        l.link(from: b_OL1.next, to: t_D_1.socket0)
        l.link(from: t_D_1.socket1, to: b_OL2.previous)
        l.link(from: t_D_1.socket2, to: t_D_2.socket2)
        l.link(from: b_OL2.next, to: t_E_1.socket1)
        l.link(from: t_E_1.socket0, to: b_OL3.previous)
        l.link(from: b_OL3.next, to: t_F_3.socket0)
        l.link(from: t_F_3.socket2, to: b_OL4.previous)
        l.link(from: b_OL4.next, to: t_A_34.socket1)
        l.link(from: t_A_34.socket0, to: b_OL1.previous)
        l.link(from: t_F_3.socket1, to: t_F_1.socket0)
        l.link(from: t_F_1.socket2, to: t_E_4.socket0)
        l.link(from: t_E_4.socket2, to: b_NE1.previous)
        l.link(from: b_NE1.next, to: t_B_4.socket2)
        l.link(from: t_B_4.socket0, to: t_A_1.socket2)
        l.link(from: t_A_1.socket0, to: t_A_34.socket3)
        l.link(from: t_E_4.socket1, to: b_NE2.previous)
        l.link(from: b_NE2.next, to: t_B_4.socket1)
        l.link(from: t_H_1.socket0, to: t_D_2.socket0)
        l.link(from: t_H_1.socket1, to: b_IL1.next)
        l.link(from: t_H_1.socket2, to: b_HL1.previous)
        l.link(from: t_H_2.socket2, to: b_HLS_P1.previous)
        l.link(from: t_H_2.socket1, to: b_HLS_P2.previous)
        l.link(from: b_HL1.next, to: t_H_2.socket0)
        l.link(from: t_H_3.socket1, to: b_HLS_P1.next)
        l.link(from: t_H_3.socket2, to: b_HLS_P2.next)
        l.link(from: t_H_3.socket0, to: b_HL2.previous)
        l.link(from: t_E_3.socket1, to: t_E_2.socket1)
        l.link(from: t_E_2.socket2, to: b_HL2.next)
        l.link(from: t_E_2.socket0, to: b_IL3.previous)
        l.link(from: t_A_1.socket1, to: t_B_3.socket0)
        l.link(from: b_NE3.next, to: t_B_3.socket1)
        l.link(from: t_B_2.socket1, to: b_NE4.next)
        l.link(from: t_B_2.socket2, to: t_B_3.socket2)
        l.link(from: t_F_2.socket2, to: t_C_3.socket1)
        l.link(from: t_C_3.socket0, to: b_NE3.previous)
        l.link(from: t_C_3.socket2, to: t_C_1.socket2)
        l.link(from: t_C_1.socket1, to: b_NE4.previous)
        l.link(from: t_F_1.socket1, to: t_F_2.socket0)
        l.link(from: b_A.previous, to: t_B_2.socket0)
        l.link(from: t_B_1.socket0, to: b_NE5.next)
        l.link(from: t_B_1.socket2, to: t_B_2.socket3)
        l.link(from: t_B_1.socket1, to: b_B.previous)
        l.link(from: b_IL4.next, to: t_D_4.socket1)
        l.link(from: t_H_4.socket0, to: t_D_4.socket2)
        l.link(from: t_H_4.socket1, to: b_HS2.next)
        l.link(from: t_D_4.socket0, to: t_A_2.socket1)
        l.link(from: t_H_4.socket2, to: b_HS1.next)
        l.link(from: t_C_4.socket1, to: b_C.next)
        l.link(from: t_C_4.socket0, to: b_NE5.previous)
        l.link(from: t_C_4.socket2, to: t_C_1.socket3)
        l.link(from: t_M_1.socket2, to: t_F_2.socket1)
        l.link(from: t_M_1.socket0, to: t_C_1.socket0)
        l.link(from: t_M_1.socket1, to: b_M1.previous)
        l.link(from: b_M1.next, to: t_Z_1.socket0)
        l.link(from: t_Z_1.socket1, to: b_M2U.previous)
        l.link(from: t_Z_1.socket2, to: b_M2D.next)
        l.link(from: b_M2U.next, to: t_Z_2.socket1)
        l.link(from: b_M2D.previous, to: t_Z_2.socket2)
        l.link(from: t_Z_2.socket0, to: t_Z_4.socket0)
        l.link(from: t_Z_4.socket1, to: b_LCF1.previous)
        l.link(from: t_Z_3.socket2, to: b_LCF2.next)
        l.link(from: t_Z_4.socket2, to: t_Z_3.socket0)
        l.link(from: b_LCF1.next, to: t_Z_5.socket1)
        l.link(from: b_LCF2.previous, to: t_Z_5.socket2)
        l.link(from: t_Z_5.socket0, to: b_M3.previous)
        l.link(from: b_M3.next, to: t_Z_3.socket1)

        // Routes

        l.newRoute("1", name: "Outer Loop", [Route.Step(b_NE1,.next, 2.0),Route.Step(b_OL1,.next, nil),Route.Step(b_OL2,.next, nil),Route.Step(b_OL3,.next, nil),Route.Step(b_NE1,.next, 5.5)])
        l.newRoute("2", name: "Inner Loop", [Route.Step(b_NE2,.next, nil),Route.Step(b_IL1,.next, nil),Route.Step(b_IL2,.next, nil),Route.Step(b_IL3,.next, nil),Route.Step(b_IL4,.next, nil),Route.Step(b_IL1,.next, nil),Route.Step(b_IL2,.next, nil),Route.Step(b_OL3,.next, nil),Route.Step(b_NE2,.next, nil)])
        l.newRoute("3", name: "Reverse Loop", [Route.Step(b_NE2,.next, nil),Route.Step(b_IL1,.next, nil),Route.Step(b_S,.previous, nil),Route.Step(b_IL3,.previous, nil),Route.Step(b_IL1,.previous, nil),Route.Step(b_NE1,.previous, nil)])
        l.newRoute("9B60D4A4-3B41-4B56-9CDB-E1264436BE1F", name: "NE4 to LCF1", [Route.Step(b_NE4,.previous, nil),Route.Step(b_M1,.next, nil),Route.Step(b_M2U,.next, nil),Route.Step(b_LCF1,.next, nil)])
        l.newRoute("9FD74AC8-C63F-4526-851E-A0AF3137A4E7", name: "Speed Test Outer Loop", [Route.Step(b_OL1,.next, nil),Route.Step(b_OL2,.next, nil),Route.Step(b_OL3,.next, nil),Route.Step(b_OL4,.next, nil),Route.Step(b_OL1,.next, nil),Route.Step(b_OL2,.next, nil),Route.Step(b_OL3,.next, nil),Route.Step(b_OL4,.next, nil)])
        l.newRoute("0D8AF32F-5077-439E-9B5E-47F61752812F", name: "NE1 > HLS_P1 > NE1", [Route.Step(b_NE1,.next, nil),Route.Step(b_OL1,.next, nil),Route.Step(b_S,.previous, nil),Route.Step(b_IL3,.previous, nil),Route.Step(b_HL2,.previous, nil),Route.Step(b_HLS_P1,.previous, 20.0),Route.Step(b_HL1,.previous, nil),Route.Step(b_IL2,.next, nil),Route.Step(b_OL3,.next, nil),Route.Step(b_NE1,.next, nil)])

        // Trains

        l.addTrain(Train(uuid: "16390", name: "460 106-8 SBB", address: 0x0006, decoder: .MFX, length: 129.0, magnetDistance: 1.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 2))
        l.addTrain(Train(uuid: "16405", name: "474 003-1 SBBC", address: 0x0015, decoder: .MFX, length: 23.0, magnetDistance: 18.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "46", name: "BLS", address: 0x002E, decoder: .MM, length: 129.0, magnetDistance: 1.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16392", name: "CFF 11414", address: 0x0008, decoder: .MFX, length: 22.0, magnetDistance: 0.5, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16391", name: "Diesel", address: 0x0007, decoder: .MFX, length: 22.0, magnetDistance: 0.5, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16396", name: "Ee 3/3 PTT 7", address: 0x000C, decoder: .MFX, length: 10.0, magnetDistance: 0.5, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16394", name: "Ee3/3 16356 SBB", address: 0x000A, decoder: .MFX, length: 10.0, magnetDistance: 0.5, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16389", name: "LION 420 202-4", address: 0x0005, decoder: .MFX, length: 100.0, magnetDistance: 13.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16407", name: "ML 003", address: 0x0017, decoder: .MFX, length: 12.0, magnetDistance: 1.0, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16393", name: "RAIL 2000", address: 0x0009, decoder: .MFX, length: 103.0, magnetDistance: 0.5, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        l.addTrain(Train(uuid: "16395", name: "Re 4/4 I 409 SBB", address: 0x000B, decoder: .MFX, length: 18.0, magnetDistance: 0.5, maxSpeed: 200, maxNumberOfLeadingReservedBlocks: 1))
        
        return l
    }
    
}
