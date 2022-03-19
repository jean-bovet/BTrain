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
        for block in blocks {
            code += "\nlet \(block.symbol) = Block(\"\(block.name)\", type: .\(block.category.rawValue)"
            code += ", center: CGPoint(x: \(block.center.x), y: \(block.center.y))"
            code += ", rotationAngle: \(block.rotationAngle.symbolicAngle)"
            code += ", waitingTime: \(block.waitingTime)"
            if let length = block.length {
                code += ", length: \(length)"
            }
            code += ")"
        }

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
        
        if let fid = block.entryFeedbackNext, let f = layout.feedback(for: fid) {
            code += "\n\(block.symbol).entryFeedbackNext = \(f.symbol).id"
        }
        if let fid = block.brakeFeedbackNext, let f = layout.feedback(for: fid) {
            code += "\n\(block.symbol).brakeFeedbackNext = \(f.symbol).id"
        }
        if let fid = block.stopFeedbackNext, let f = layout.feedback(for: fid) {
            code += "\n\(block.symbol).stopFeedbackNext = \(f.symbol).id"
        }
        
        if let fid = block.entryFeedbackPrevious, let f = layout.feedback(for: fid) {
            code += "\n\(block.symbol).entryFeedbackPrevious = \(f.symbol).id"
        }
        if let fid = block.brakeFeedbackPrevious, let f = layout.feedback(for: fid) {
            code += "\n\(block.symbol).brakeFeedbackPrevious = \(f.symbol).id"
        }
        if let fid = block.stopFeedbackPrevious, let f = layout.feedback(for: fid) {
            code += "\n\(block.symbol).stopFeedbackPrevious = \(f.symbol).id"
        }

        for (index, bf) in block.feedbacks.enumerated() {
            if let distance = bf.distance {
                code += "\n\(block.symbol).feedbacks[\(index)].distance = \(distance)"
            }
        }

        if let brakingSpeed = block.brakingSpeed {
            code += "\n\(block.symbol).brakingSpeed = \(brakingSpeed)"
        }
    }
            
    func add(turnouts: [Turnout]) {
        for turnout in turnouts {
            code += "\nlet \(turnout.symbol) = Turnout(\"\(turnout.name)\", type: .\(turnout.category.rawValue), address: .init(\(turnout.addressValue),"
            if let ap = turnout.addressProtocol {
                code += ".\(ap)"
            } else {
                code += "nil"
            }
            code += ")"
            if turnout.doubleAddress {
                code += ", address2: .init(\(turnout.address2Value),"
                if let ap = turnout.addressProtocol {
                    code += ".\(ap)"
                } else {
                    code += "nil"
                }
                code += ")"
            }
            code += ", state: .\(turnout.state.rawValue)"
            code += ", center: CGPoint(x: \(turnout.center.x), y: \(turnout.center.y))"
            code += ", rotationAngle: \(turnout.rotationAngle.symbolicAngle)"
            if let length = turnout.length {
                code += ", length: \(length)"
            }
            code += ")"
        }

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
        if let blockId = socket.block, let block = layout.block(for: blockId) {
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
            if let block = layout.block(for: step.blockId), let direction = step.direction {
                if !content.isEmpty {
                    content += ","
                }
                content += "Route.Step(\(block.symbol),.\(direction.rawValue), \(optionalString(step.waitingTime)))"
            }
        }
        code += "\nl.newRoute(\"\(route.id)\", name: \"\(route.name)\", [\(content)])"
    }
    
    func optionalString(_ value: Double?) -> String {
        if let value = value {
            return "\(value)"
        } else {
            return "nil"
        }
    }

    func add(trains: [Train]) {
        for train in trains {
            code += "\nl.addTrain(Train(uuid: \"\(train.id)\""
            code += ", name: \"\(train.name)\""
            code += ", address: \(train.address.toHex())"
            code += ", decoder: .\(train.decoder)"
            if let length = train.locomotiveLength {
                code += ", locomotiveLength: \(length)"
            }
            if let length = train.wagonsLength {
                code += ", wagonsLength: \(length)"
            }
            if let magnetDistance = train.magnetDistance {
                code += ", magnetDistance: \(magnetDistance)"
            }
            code += ", maxSpeed: \(train.speed.maxSpeed)"
            code += ", maxNumberOfLeadingReservedBlocks: \(train.maxNumberOfLeadingReservedBlocks)"
            code += "))"
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

private extension Train {
    
    var symbol: String {
        "tr_\(name.sanitizedSymbol)"
    }
}

private extension Route {
    
    var symbol: String {
        "r_\(name.sanitizedSymbol)"
    }
}

private extension String {
    
    var sanitizedSymbol: String {
        return replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "/", with: "_")
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
