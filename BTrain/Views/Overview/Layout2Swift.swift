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

// This class takes a layout and generates the Swift code
// that can re-create this layout programmaticaly. Useful for debugging
// and unit testing.
final class Layout2Swift {
    
    let layout: Layout
    
    var code = ""
    
    init(layout: Layout) {
        self.layout = layout
    }
    
    func swift() -> String {
        code = "let l = Layout()"

        write(section: "Blocks")
        add(blocks: layout.blocks)

        write(section: "Feedbacks")
        add(feedbacks: layout.feedbacks)

        write(section: "Turnouts")
        add(turnouts: layout.turnouts)

        write(section: "Transitions")
        add(transitions: layout.transitions)

        write(section: "Routes")
        add(routes: layout.routes)

        write(section: "Trains")
        add(trains: layout.trains)
        
        return code
    }

    func write(section: String) {
        code += "\n\n// \(section)\n"
    }
    
    func add(blocks: [Block]) {
        // let b1 = Block("IL1", type: .free, center: CGPoint(x: 160, y: 250), rotationAngle: -.pi/2)
        for block in blocks {
            code += "\nlet \(block.symbol) = Block(\"\(block.name)\", type: .\(block.category.rawValue), center: CGPoint(x: \(block.center.x), y: \(block.center.y)), rotationAngle: \(block.rotationAngle.symbolicAngle))"
        }

        //        l.add([b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11])
        var content = ""
        for block in blocks {
            if !content.isEmpty {
                content += ","
            }
            content += "\(block.symbol)"
        }
        code += "\nl.add([\(content)])"
    }
 
    func add(feedbacks: [Feedback]) {
        for feedback in feedbacks {
            code += "\nlet \(feedback.symbol) = Feedback(\"\(feedback.name)\", deviceID: \(feedback.deviceID), contactID: \(feedback.contactID))"
        }
        
        var content = ""
        for feedback in feedbacks {
            if !content.isEmpty {
                content += ","
            }
            content += "\(feedback.symbol)"
        }
        code += "\nl.feedbacks.append(contentsOf: [\(content)])"

        for block in layout.blocks {
            assignFeedbacks(to: block)
        }
    }
        
    func assignFeedbacks(to block: Block) {
        if block.feedbacks.isEmpty {
            return
        }
        
        var content = ""
        for feedback in block.feedbacks {
            if let feedback = layout.feedback(for: feedback.feedbackId) {
                if !content.isEmpty {
                    content += ","
                }
                content += "\(feedback.symbol)"
            }
        }
        code += "\nl.assign(\(block.symbol), [\(content)])"
    }
            
    func add(turnouts: [Turnout]) {
//        let t1 = Turnout("D.2", type: .crossing, address: .init(14, .MFX), address2: .init(15, .DCC), state: .straight01, center: CGPoint(x: 280, y: 140))
        for turnout in turnouts {
            code += "\nlet \(turnout.symbol) = Turnout(\"\(turnout.name)\", type: .\(turnout.category.rawValue), address: .init(\(turnout.addressValue), .\(turnout.addressProtocol))"
            if turnout.doubleAddress {
                code += ", address2: .init(\(turnout.address2Value), .\(turnout.addressProtocol))"
            }
            code += ", state: .\(turnout.state.rawValue), center: CGPoint(x: \(turnout.center.x), y: \(turnout.center.y)), rotationAngle: \(turnout.rotationAngle.symbolicAngle))"
        }

//        l.turnouts.append(contentsOf: [t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12])
        var content = ""
        for turnout in turnouts {
            if !content.isEmpty {
                content += ","
            }
            content += "\(turnout.symbol)"
        }
        code += "\nl.turnouts.append(contentsOf: [\(content)])"
    }

    func add(transitions: [Transition]) {
        //         l.link(from: b1.next, to: t1.socket0)
        for transition in transitions {
            code += "\nl.link(from: \(symbol(for: transition.a)), to: \(symbol(for: transition.b)))"
        }
    }
    
    func symbol(for socket: Socket) -> String {
        if let blockId = socket.block, let block = layout.mutableBlock(for: blockId) {
            if socket.socketId == Block.nextSocket {
                return "\(block.symbol).next"
            } else if socket.socketId == Block.previousSocket {
                return "\(block.symbol).previous"
            }
        } else if let turnoutId = socket.turnout, let turnout = layout.turnout(for: turnoutId) {
            return "\(turnout.symbol).socket\(socket.socketId!)"
        }
        fatalError("Unsupported socket configuration: \(socket)")
    }
    
    func add(routes: [Route]) {
        for route in routes {
            write(route: route)
        }
    }

    func write(route: Route) {
        guard !route.automatic else {
            return
        }
        
        //        l.newRoute("1", name: "Outer Loop", [(b10, .next), (b6, .next), (b7, .next), (b8, .next), (b10, .next)])
        var content = ""
        for step in route.steps {
            if !content.isEmpty {
                content += ","
            }
            let block = layout.mutableBlock(for: step.blockId)!
            content += "(\(block.symbol),.\(step.direction.rawValue))"
        }
        code += "\nl.newRoute(\"\(route.id)\", name: \"\(route.name)\", [\(content)])"
    }
    
    func add(trains: [Train]) {
//        l.newTrain("1", name: "Rail 2000", address: .init(0x4009, .MFX))
        for train in trains {
            if let decoderType = train.addressDecoderType {
                code += "\nl.newTrain(\"\(train.id)\", name: \"\(train.name)\", address: .init(\(train.addressValue.toHex()), .\(decoderType)))"
            } else {
                code += "\nl.newTrain(\"\(train.id)\", name: \"\(train.name)\", address: .init(\(train.addressValue.toHex()), nil))"
            }
        }
    }
}

private extension Block {
    
    var symbol: String {
        "b_\(name.sanitizedSymbol)"
    }
}

private extension Turnout {
    
    var symbol: String {
        "t_\(name.sanitizedSymbol)"
    }
}

private extension Feedback {
    
    var symbol: String {
        "f_\(name.sanitizedSymbol)"
    }
}

private extension String {
    
    var sanitizedSymbol: String {
        replacingOccurrences(of: ".", with: "_")
    }
    
}

private extension CGFloat {
    
    var symbolicAngle: String {
        if self ==~ .pi {
            return ".pi"
        }
        if self ==~ -.pi {
            return "-.pi"
        }
        
        if self ==~ .pi/2 {
            return ".pi/2"
        }
        if self ==~ -.pi/2 {
            return "-.pi/2"
        }

        if self ==~ .pi/4 {
            return ".pi/4"
        }
        if self ==~ -.pi/4 {
            return "-.pi/4"
        }

        return "\(self)"
    }
}

infix operator ==~ : ComparisonPrecedence

func ==~(lhs: CGFloat, rhs: CGFloat) -> Bool  {
    return abs(rhs-lhs) < 0.01
}
