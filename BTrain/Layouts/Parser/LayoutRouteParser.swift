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

final class LayoutRouteParser {
    
    let layout: Layout
    
    var blocks = Set<Block>()
    var feedbacks = Set<Feedback>()
    
    var route: Route!

    var trains = [Train]()

    struct TurnoutSpec {
        let id: Identifier<Turnout>
        let fromSocket: Int
        let toSocket: Int
    }

    // Map of block index to turnout spec. In other words,
    // this map contains a turnout spec, if specified, related
    // to a specific block index in the route string.
    var blockTurnouts = [Int:[TurnoutSpec]]()
    
    let sp: LayoutStringParser
    
    init(ls: String, id: String, layout: Layout) {
        self.sp = LayoutStringParser(ls: ls)
        self.layout = layout
    }
    
    func parseRouteName() -> Route {
        let routeName = sp.matchString(":")
        guard !routeName.isEmpty else {
            fatalError("Route name must be specified for each route")
        }
        
        sp.eat(":")
        
        return Route(uuid: routeName, automatic: false)
    }
    
    func parse() {
        route = parseRouteName()
        
        while (sp.more) {
            if sp.matches("!{") {
                parseBlock(type: .station, direction: .previous)
            } else if sp.matches("{") {
                parseBlock(type: .station, direction: .next)
            } else if sp.matches("![") {
                parseBlock(type: .free, direction: .previous)
            } else if sp.matches("[") {
                parseBlock(type: .free, direction: .next)
            } else if sp.matches("<") {
                parseTurnouts()
            } else if sp.matches(" ") {
                // Ignore white space
            } else {
                fatalError("Unexpected character '\(sp.c)' found while parsing block definition")
            }
        }
        
        addTransitions()
    }
    
    func addTransitions() {
        for index in 0..<route.steps.count {
            if index + 1 == route.steps.count {
                // We have reached the last step, there is no transitions out of it
                continue
            }
                        
            let step = route.steps[index]
            let nextStep = route.steps[index+1]
                        
            if let turnouts = blockTurnouts[index] {
                // There exist one or more turnouts between these two blocks
                //┌─────────┐
                //│ Block 1 │────▶  T1 | T2 | TX ──────────────┐
                //└─────────┘                     ┌─────────┐  │
                //                                │ Block 2 │◀─┘
                //                                └─────────┘
                //┌─────────┐                          ┌─────────┐
                //│ Block 1 │────▶  T1 | T2 | TX  ────▶│ Block 2 │
                //└─────────┘                          └─────────┘
                for (index, turnout) in turnouts.enumerated() {
                    if index == 0 {
                        layout.link("\(step.blockId)-\(turnout.id)",
                                    from: step.exitSocket,
                                    to: Socket.turnout(turnout.id, socketId: turnout.fromSocket))
                    }
                    
                    if index > 0 && index < turnouts.count {
                        let previousTurnout = turnouts[index - 1]
                        layout.link("\(previousTurnout.id)-\(turnout.id)",
                                    from: Socket.turnout(previousTurnout.id, socketId: previousTurnout.toSocket),
                                    to: Socket.turnout(turnout.id, socketId: turnout.fromSocket))
                    }

                    if index == turnouts.count - 1 {
                        layout.link("\(turnout.id)-\(nextStep)",
                                    from: Socket.turnout(turnout.id, socketId: turnout.toSocket),
                                    to: nextStep.entrySocket)
                    }
                }
            } else {
                // No turnout between these two blocks
                //┌─────────┐                     ┌─────────┐
                //│ Block 1 │────────────────────▶│ Block 2 │
                //└─────────┘                     └─────────┘
                //
                //┌─────────┐
                //│ Block 1 │──────────────────────────────────┐
                //└─────────┘                     ┌─────────┐  │
                //                                │ Block 2 │◀─┘
                //                                └─────────┘
                layout.link("\(step.blockId)-\(nextStep.blockId)",
                            from: step.exitSocket,
                            to: nextStep.entrySocket)
            }
        }
    }
            
    func parseBlock(type: Block.Category, direction: Direction) {
        let block: Block
        let newBlock: Bool
        
        let blockHeader = parseBlockHeader(type: type, direction: direction)
        
        // Parse the optional digit that indicates a reference to an existing block
        // Example: { ≏ ≏ } [[ ≏ 🚂 ≏ ]] [[ ≏ ≏ ]] {b0 ≏ ≏ }
        if let blockName = blockHeader.blockName {
            let blockID = Identifier<Block>(uuid: blockName)
            if let existingBlock = layout.block(for: blockID) {
                block = existingBlock
                assert(block.category == type, "The existing block \(blockID) does not match the type defined in the ASCII representation")
                assert(block.reserved == blockHeader.reserved, "The existing block \(blockID) does not match the reserved type defined in the ASCII representation")
                assert(block.reserved?.direction == blockHeader.reserved?.direction, "The existing block \(blockID) does not match the reserved type defined in the ASCII representation")
                newBlock = false
            } else {
                block = Block(blockID.uuid, type: type)
                block.reserved = blockHeader.reserved
                newBlock = true
            }
        } else {
            // Note: use a UUID that is using the number of blocks created so far
            // so the UUID is easy to unit test
            block = Block(String(route.steps.count), type: type)
            block.reserved = blockHeader.reserved
            newBlock = true
        }
                    
        var feedbackIndex = 0
        var parsingBlock = true
        while (sp.more && parsingBlock) {
            if sp.matches("🛑🚂") {
                // Stopped train
                parseTrain(feedbackIndex: feedbackIndex, block: block, speed: 0)
            } else if sp.matches("🟨🚂") {
                // Braking train
                parseTrain(feedbackIndex: feedbackIndex, block: block, speed: LayoutFactory.DefaultBrakingSpeed)
            } else if sp.matches("}}") {
                // End of Station block
                assert(type == .station, "Expected end of station block")
                parsingBlock = false
            } else if sp.matches("]]") {
                // End of Free track block
                assert(type == .free, "Expected end of free track block")
                parsingBlock = false
            } else if sp.matches("}") {
                // End of Station block
                assert(type == .station, "Expected end of station block")
                parsingBlock = false
            } else if sp.matches("]") {
                // End of Free track block
                assert(type == .free, "Expected end of free track block")
                parsingBlock = false
            } else if sp.matches("🚂") {
                parseTrain(feedbackIndex: feedbackIndex, block: block, speed: LayoutFactory.DefaultSpeed)
            } else if sp.matches("≏") {
                parseFeedback(detected: false, newBlock: newBlock, block: block, feedbackIndex: &feedbackIndex)
            } else if sp.matches("≡") {
                parseFeedback(detected: true, newBlock: newBlock, block: block, feedbackIndex: &feedbackIndex)
            } else if sp.matches(" ") {
                // ignore white space
            } else {
                fatalError("Unknown character '\(sp.c)'")
            }
        }
        
        blocks.insert(block)
        route.steps.append(Route.Step(String(route.steps.count), block.id, direction))
    }
 
    struct BlockHeader {
        var blockName: String?
        var reserved: Reservation?
    }
    
    func parseBlockHeader(type: Block.Category, direction: Direction) -> BlockHeader {
        var header = BlockHeader()

        var reservedTrainNumber: String?
        if sp.matches("r") {
            reservedTrainNumber = String(sp.eat())
        }
        
        var reserved  = false
        if sp.matches("[") {
            reserved = true
            assert(type == .free, "Invalid reserved block definition")
        } else if sp.matches("{") {
            reserved = true
            assert(type == .station, "Invalid reserved block definition")
        }

        if reserved {
            if let reservedTrainNumber = reservedTrainNumber {
                header.reserved = .init(trainId: Identifier<Train>(uuid: reservedTrainNumber), direction: direction)
            } else {
                assertionFailure("A reserved block must have a reservation train number specified!")
            }
        }
        
        let blockName = sp.matchString()
        if blockName.isEmpty {
            assertionFailure("Expecting a block name")
        } else {
            header.blockName = blockName
        }
        return header
    }
        
    func parseTrain(feedbackIndex: Int, block: Block, speed: UInt16) {
        let uuid: String
        if let n = sp.matchesInteger() {
            uuid = String(n)
        } else {
            // Note: by default, let's use the route.id for the train id
            uuid = route.id.uuid
        }
        
        if let train = trains.first(where: { $0.id.uuid == uuid }) {
            assert(train.speed.kph == speed, "Mismatching speed definition for train \(uuid)")
            assert(train.position == feedbackIndex, "Mismatching position definition for train \(uuid)")
            block.train = Block.TrainInstance(train.id, .next)
        } else {
            let train = Train(uuid: uuid)
            train.position = feedbackIndex
            train.routeIndex = route.steps.count
            train.speed = .init(kph: speed, decoderType: .MFX)
            train.routeId = route.id
            block.train = Block.TrainInstance(train.id, .next)
            trains.append(train)
        }
    }
        
    func parseFeedback(detected: Bool, newBlock: Bool, block: Block, feedbackIndex: inout Int) {
        if newBlock {
            let f = Feedback("f\(block.id.uuid)\(block.feedbacks.count+1)")
            f.detected = detected
            block.add(f.id)
            feedbacks.insert(f)
        } else {
            let feedback = block.feedbacks[feedbackIndex]
            let f = feedbacks.first(where: { $0.id == feedback.feedbackId })!
            assert(f.detected == detected, "The existing feedback does not match the `reserved` defined in the ASCII representation")
            f.detected = detected
        }
        feedbackIndex += 1
    }
    
    // <t0(0,1),s>
    // <t0,0>
    // <t0>
    // <t0(0,1)>
    // <r0<t0>> : reserved turnout
    // Where the state portion can be: s, l, r, s01, s23, b21, b03
    func parseTurnouts() {
        var reservedTrainNumber: String?
        if sp.matches("r") {
            reservedTrainNumber = String(sp.eat())
            sp.eat("<")
        }
        
        let turnoutName = sp.matchString(["(", ",", ">"])
        guard !turnoutName.isEmpty else {
            assertionFailure("Turnout must have its name specified")
            return
        }

        // Default values, if not specified
        var fromSocket = 0
        var toSocket = 1
        var state = Turnout.State.straight
        
        // See if the socket definition is specified
        if sp.matches("(") {
            fromSocket = Int(String(sp.eat()))!
            assert(sp.matches(","), "Expecting ',' before toSocket definition")
            toSocket = Int(String(sp.eat()))!
            assert(sp.matches(")"), "Expecting closing ')' after socket definition")
        }

        // See if the state of the turnout is specified
        if sp.matches(",") {
            if sp.matches("s01") {
                state = .straight01
            } else if sp.matches("s23") {
                state = .straight23
            } else if sp.matches("b21") {
                state = .branch21
            } else if sp.matches("b03") {
                state = .branch03
            } else if sp.matches("s") {
                state = .straight
            } else if sp.matches("l") {
                state = .branchLeft
            } else if sp.matches("r") {
                state = .branchRight
            } else {
                assertionFailure("Invalid turnout state")
            }
        }

        assert(sp.matches(">"), "Expecting closing turnout character")

        if reservedTrainNumber != nil {
            assert(sp.matches(">"), "Expecting closing reserved turnout character")
        }
        
        let turnoutId = Identifier<Turnout>(uuid: turnoutName)
        if let existingTurnout = layout.turnout(for: turnoutId) {
            assert(existingTurnout.state == state, "Mismatching turnout state for turnout \(turnoutName)")
            assert(existingTurnout.reserved?.uuid == reservedTrainNumber, "Mismatching turnout reservation for turnout \(turnoutName)")
        } else {
            let turnout = Turnout(turnoutName, type: .singleRight, address: 0, state: state)
            if let reservedTrainNumber = reservedTrainNumber {
                turnout.reserved = Identifier<Train>(uuid: reservedTrainNumber)
            }
            layout.turnouts.append(turnout)
        }
        
        var turnouts = blockTurnouts[route.steps.count-1]
        if turnouts == nil {
            turnouts = [TurnoutSpec]()
        }
        let t = TurnoutSpec(id: turnoutId, fromSocket: fromSocket, toSocket: toSocket)
        turnouts!.append(t)
        blockTurnouts[route.steps.count-1] = turnouts!
    }

}

extension Route.Step {
    
    // Returns the socket where the train will exit
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var exitSocket: Socket {
        if direction == .next {
            return Socket.block(blockId, socketId: 1)
        } else {
            return Socket.block(blockId, socketId: 0)
        }
    }
    
    // Returns the socket where the train will enter
    // the block represented by this step, taking
    // into account the direction of travel of the train.
    var entrySocket: Socket {
        if direction == .next {
            return Socket.block(blockId, socketId: 0)
        } else {
            return Socket.block(blockId, socketId: 1)
        }
    }
}
