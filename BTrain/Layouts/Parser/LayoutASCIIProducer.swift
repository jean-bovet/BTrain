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

final class LayoutASCIIProducer {
    
    let layout: Layout
    let resolver: RouteResolver
    
    init(layout: Layout) {
        self.layout = layout
        self.resolver = RouteResolver(layout: layout)
    }
    
    func stringFrom(route: Route, trainId: Identifier<Train>?) throws -> String {
        var text = ""
                
        let resolvedSteps = try resolver.resolve(steps: ArraySlice(route.steps), trainId: trainId)
        for step in resolvedSteps {
            if let turnoutId = step.turnoutId {
                addSpace(&text)
                try generateTurnout(turnoutId: turnoutId, step: step, text: &text)
            } else if let blockId = step.blockId {
                addSpace(&text)
                try generateBlock(blockId: blockId, step: step, text: &text)
            }
        }
        
        return text
    }

    private func generateBlock(blockId: Identifier<Block>, step: Route.Step, text: inout String) throws {
        guard let block = layout.block(for: blockId) else {
            throw LayoutError.blockNotFound(blockId: blockId)
        }
        
        if step.direction == .previous {
            text += "!"
        }
        switch(block.category) {
        case .station:
            text += "{"
            if let reserved = block.reserved {
                text += "r\(reserved.trainId)"
                text += "{"
            }
            text += "\(block.id)"
        case .free, .sidingNext, .sidingPrevious:
            text += "["
            if let reserved = block.reserved {
                text += "r\(reserved.trainId)"
                text += "["
            }
            text += "\(block.id)"
        }
                    
        if let part = train(block, 0) {
            text += " " + part
        }

        for (index, feedback) in block.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId) else {
                throw LayoutError.feedbackNotFound(feedbackId: feedback.feedbackId)
            }
            if f.detected {
                text += " ≡"
            } else {
                text += " ≏"
            }
            if let part = train(block, index+1) {
                text += " " + part
            }
        }
        
        switch(block.category) {
        case .station:
            if block.reserved != nil {
                text += " }}"
            } else {
                text += " }"
            }
        case .free, .sidingNext, .sidingPrevious:
            if block.reserved != nil {
                text += " ]]"
            } else {
                text += " ]"
            }
        }
    }
    
    func generateTurnout(turnoutId: Identifier<Turnout>, step: Route.Step, text: inout String) throws {
        guard let turnout = layout.turnout(for: turnoutId) else {
            throw LayoutError.turnoutNotFound(turnoutId: turnoutId)
        }
        
        text += "<"
        if let reserved = turnout.reserved?.train {
            text += "r\(reserved)"
            text += "<"
        }

        // <t0{sl}(0,1),s>
        text += "\(turnout.id)"
        text += "{\(turnoutType(turnout))}"
        text += "(\(try step.entrySocketId()),\(try step.exitSocketId()))"
        if let state = turnoutState(turnout) {
            text += ",\(state)"
        }
        if turnout.reserved != nil {
            text += ">"
        }
        text += ">"
    }
    
    func turnoutState(_ turnout: Turnout) -> String? {
        switch turnout.state {
        case .straight:
            return "s"
        case .branch:
            return "b"
        case .branchLeft:
            return "l"
        case .branchRight:
            return "r"
        case .straight01:
            return "s01"
        case .straight23:
            return "s23"
        case .branch03:
            return "b03"
        case .branch21:
            return "b21"
        case .invalid:
            return nil
        }
    }
    
    func turnoutType(_ turnout: Turnout) -> String {
        switch turnout.category {
        case .singleLeft:
            return "sl"
        case .singleRight:
            return "sr"
        case .threeWay:
            return "tw"
        case .doubleSlip:
            return "ds"
        case .doubleSlip2:
            return "ds2"
        }
    }
        
    func train(_ block: Block, _ position: Int) -> String? {
        guard let trainInstance = block.train else {
            return nil
        }
              
        guard let train = layout.train(for: trainInstance.trainId) else {
            return nil
        }

        if trainInstance.parts.isEmpty && train.position == position {
            return stringFrom(train)
        } else if let part = trainInstance.parts[position] {
            switch part {
            case .locomotive:
                return stringFrom(train)
            case .wagon:
                return "💺\(train.id)"
            }
        } else {
            return nil
        }
    }
    
    func stringFrom(_ train: Train) -> String {
        switch train.state {
        case .running:
            return "🚂\(train.id)"
        case .braking:
            return "🟨🚂\(train.id)"
        case .stopping:
            return "🟧🚂\(train.id)"
        case .stopped:
            return "🛑🚂\(train.id)"
        }
    }
    
    private func addSpace(_ text: inout String) {
        if text.isEmpty {
            return
        }
        if text.last == " " {
            return
        }
        text += " "
    }
    
}
