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

// This layout is used to test the various configuration of the block and turnout elements
final class LayoutGCreator: LayoutCreating {
    
    static let id = Identifier<Layout>(uuid: "layout-g")

    var name: String {
        return "Layout with All Elements"
    }
    
    func newLayout() -> Layout {
        let layout = Layout(uuid: LayoutGCreator.id.uuid)
        layout.name = name

        // Blocks
        let b1 = Block("1", type: .station)
        let b2 = Block("2", type: .free)
        let b3 = Block("3", type: .station)
        let b4 = Block("4", type: .free)
        let b5 = Block("5", type: .free)
        let b6 = Block("6", type: .free)
        let b7 = Block("7", type: .free)
        let b8 = Block("8", type: .free)
        let blocks = [b1, b2, b3, b4, b5, b6, b7, b8]
        layout.add(blocks)
        
        let deltaAngle: Double = .pi / 4
        
        let radius = 200.0
        for (index, block) in blocks.enumerated() {
            let angle = Double(index) * deltaAngle
            block.center = CGPoint(x: 240 + cos(angle) * radius, y: 240 + sin(angle) * radius)
            block.rotationAngle = Double(index) * deltaAngle + .pi/2
        }

        // Feedbacks
        for index in 0...7 {
            let f1 = Feedback("f\(index+1)1", deviceID: UInt16(index), contactID: 1)
            let f2 = Feedback("f\(index+1)2", deviceID: UInt16(index), contactID: 2)
            layout.feedbacks.append(contentsOf: [f1, f2])
            blocks[index].assign([f1.id, f2.id])
        }

        // Turnouts
        let t1 = Turnout("1", type: .singleRight, address: 3, state: .straight, center: CGPoint(x: 500, y: 80))
        let t2 = Turnout("2", type: .singleRight, address: 3, state: .branchRight, center: CGPoint(x: 550, y: 80))
        
        let t3 = Turnout("3", type: .singleLeft, address: 4, state: .straight, center: CGPoint(x: 500, y: 140))
        let t4 = Turnout("4", type: .singleLeft, address: 4, state: .branchLeft, center: CGPoint(x: 550, y: 140))
        
        let t5 = Turnout("5", type: .threeWay, address: 5, state: .straight, center: CGPoint(x: 500, y: 200))
        let t6 = Turnout("6", type: .threeWay, address: 5, state: .branchLeft, center: CGPoint(x: 550, y: 200))
        let t7 = Turnout("7", type: .threeWay, address: 5, state: .branchRight, center: CGPoint(x: 600, y: 200))
        
        let t8 = Turnout("8", type: .doubleSlip2, address: 6, state: .straight01, center: CGPoint(x: 500, y: 260))
        let t9 = Turnout("9", type: .doubleSlip2, address: 6, state: .straight23, center: CGPoint(x: 550, y: 260))
        let t10 = Turnout("10", type: .doubleSlip2, address: 6, state: .branch03, center: CGPoint(x: 600, y: 260))
        let t11 = Turnout("11", type: .doubleSlip2, address: 6, state: .branch21, center: CGPoint(x: 650, y: 260)) 

        layout.turnouts.append(contentsOf: [t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11])
        
        // Next transitions
        layout.link("1", from: b1.next, to: b2.previous)
        layout.link("1", from: b2.next, to: b3.previous)
        layout.link("1", from: b3.next, to: b4.previous)
        layout.link("1", from: b4.next, to: b5.previous)
        layout.link("1", from: b5.next, to: b6.previous)
        layout.link("1", from: b6.next, to: b7.previous)
        layout.link("1", from: b7.next, to: b8.previous)
        layout.link("1", from: b8.next, to: b1.previous)
        
        // Train
        for index in 1...8 {
            let tr1 = Train(uuid: "\(index)")
            tr1.name = "Loco \(index)"
            tr1.address = .init(UInt32(0x4009 + index), .MFX)
            layout.trains.append(tr1)
            blocks[index-1].train = Block.TrainInstance(tr1.id, .next)
        }

        return layout
    }
    
}
