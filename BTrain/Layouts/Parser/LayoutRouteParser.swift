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
            } else if sp.matches("|[") {
                parseBlock(type: .sidingPrevious, direction: .next)
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

            layout.link(from: step.exitSocket!,
                        to: nextStep.entrySocket!)
        }
    }
            
    func parseBlock(type: Block.Category, direction: Direction) {
        let block: Block
        let newBlock: Bool
        
        let blockHeader = parseBlockHeader(type: type, direction: direction)
        
        // Parse the optional digit that indicates a reference to an existing block
        // Example: { ≏ ≏ } [[ ≏ 🟢🚂 ≏ ]] [[ ≏ ≏ ]] {b0 ≏ ≏ }
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
                    
        if direction == .previous {
            let index = sp.index
            let numberOfFeedbacks = parseNumberOfFeedbacks(block: block, newBlock: newBlock, type: type)
            sp.index = index
            parseBlockContent(block: block, newBlock: newBlock, type: type, numberOfFeedbacks: numberOfFeedbacks)
        } else {
            parseBlockContent(block: block, newBlock: newBlock, type: type, numberOfFeedbacks: nil)
        }
        
        blocks.insert(block)
        route.steps.append(Route.Step(String(route.steps.count), block.id, direction))
    }
 
    enum BlockContentType {
        case stoppedLoc
        case brakingLoc
        case runningLoc
        case runningLimitedLoc

        case wagon
        
        case endStation(reserved: Bool)
        case endFreeOrSidingPrevious(reserved: Bool)
        case endFreeOrSidingNext(reserved: Bool)
        
        case feedback(detected: Bool)
    }
    
    typealias BlockContentCallback = (BlockContentType) -> Void
    
    func parseNumberOfFeedbacks(block: Block, newBlock: Bool, type: Block.Category) -> Int {
        var currentFeedbackIndex = 0
        parseBlockContent(block: block, newBlock: newBlock, type: type) { contentType in
            switch(contentType) {
            case .stoppedLoc, .runningLoc, .runningLimitedLoc, .wagon:
                _ = parseUUID()
            case .brakingLoc:
                _ = parseTrainSpeed()
                _ = parseUUID()
            case .endStation(reserved: _):
                break
            case .endFreeOrSidingPrevious(reserved: _):
                break
            case .endFreeOrSidingNext(reserved: _):
                break
            case .feedback(detected: _):
                currentFeedbackIndex += 1
            }
        }
        return currentFeedbackIndex
    }
    
    func parseBlockContent(block: Block, newBlock: Bool, type: Block.Category, numberOfFeedbacks: Int?) {
        var currentFeedbackIndex = 0
        parseBlockContent(block: block, newBlock: newBlock, type: type) { contentType in
            let feedbackIndex: Int
            let position: Int
            if let numberOfFeedbacks = numberOfFeedbacks {
                feedbackIndex = numberOfFeedbacks - currentFeedbackIndex - 1
                position = numberOfFeedbacks - currentFeedbackIndex
            } else {
                feedbackIndex = currentFeedbackIndex
                position = currentFeedbackIndex
            }
            
            switch(contentType) {
            case .stoppedLoc:
                parseTrain(position: position, block: block, speed: 0)
                
            case .brakingLoc:
                parseTrain(position: position, block: block, speed: parseTrainSpeed())
                
            case .runningLoc:
                parseTrain(position: position, block: block, speed: LayoutFactory.DefaultMaximumSpeed)
                
            case .runningLimitedLoc:
                parseTrain(position: position, block: block, speed: LayoutFactory.DefaultLimitedSpeed)
                
            case .wagon:
                parseWagon(position: position, block: block)

            case .endStation(reserved: let reserved):
                assert(type == .station, "Expected end of station block \(reserved)")
                
            case .endFreeOrSidingPrevious(reserved: let reserved):
                assert(type == .free || type == .sidingPrevious, "Expected end of .free or .sidingPrevious track block \(reserved)")

            case .endFreeOrSidingNext(reserved: let reserved):
                assert(type == .free, "Expected end of .free (but soon to be .sidingNext) track block \(reserved)")
                block.category = .sidingNext // Change to sidingNext here because that's only when we know if it is one!
                
            case .feedback(detected: let detected):
                assert(feedbackIndex >= 0, "Invalid feedback index \(feedbackIndex)")
                parseFeedback(detected: detected, newBlock: newBlock, block: block, feedbackIndex: feedbackIndex, reverseOrder: numberOfFeedbacks != nil)
                currentFeedbackIndex += 1
            }
        }
    }
    
    func parseBlockContent(block: Block, newBlock: Bool, type: Block.Category, callback: BlockContentCallback) {
        var parsingBlock = true
        while (sp.more && parsingBlock) {
            if sp.matches("🔴🚂") {
                callback(.stoppedLoc)
            } else if sp.matches("🟡") {
                callback(.brakingLoc)
            } else if sp.matches("🟢🚂") {
                callback(.runningLoc)
            } else if sp.matches("🔵🚂") {
                callback(.runningLimitedLoc)
            } else if sp.matches("}}") {
                callback(.endStation(reserved: true))
                parsingBlock = false
            } else if sp.matches("]]|") {
                callback(.endFreeOrSidingNext(reserved: true))
                parsingBlock = false
            } else if sp.matches("]]") {
                callback(.endFreeOrSidingPrevious(reserved: true))
                parsingBlock = false
            } else if sp.matches("}") {
                callback(.endStation(reserved: false))
                parsingBlock = false
            } else if sp.matches("]|") {
                callback(.endFreeOrSidingNext(reserved: false))
                parsingBlock = false
            } else if sp.matches("]") {
                callback(.endFreeOrSidingPrevious(reserved: true))
                parsingBlock = false
            } else if sp.matches("≏") {
                callback(.feedback(detected: false))
            } else if sp.matches("≡") {
                callback(.feedback(detected: true))
            } else if sp.matches(" ") {
                // ignore white space
            } else if sp.matches("💺") {
                callback(.wagon)
            } else {
                fatalError("Unknown character '\(sp.c)'")
            }
        }
    }
    
    struct BlockHeader {
        var blockName: String?
        var reserved: Reservation?
    }
    
    func parseBlockHeader(type: Block.Category, direction: Direction) -> BlockHeader {
        var header = BlockHeader()

        var reservedTrainNumber: String?
        if sp.matches("r") {
            if let n = sp.matchesInteger() {
                reservedTrainNumber = String(n)
            } else {
                assertionFailure("Unexpected train number reservation")
            }
        }
        
        var reserved  = false
        if sp.matches("[") {
            reserved = true
            assert(type == .free || type == .sidingPrevious, "Invalid reserved block definition")
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

    func parseUUID() -> String {
        let uuid: String
        if let n = sp.matchesInteger() {
            uuid = String(n)
        } else {
            // Note: by default, let's use the route.id for the train id
            uuid = route.id.uuid
        }
        return uuid
    }
    
    func parseTrainSpeed() -> TrainSpeed.UnitKph {
        let speed: TrainSpeed.UnitKph
        if let specifiedSpeed = sp.matchesInteger() {
            speed = TrainSpeed.UnitKph(specifiedSpeed)
        } else {
            speed = LayoutFactory.DefaultBrakingSpeed
        }
        _ = sp.matches("🚂")
        return speed
    }
    
    func parseTrain(position: Int, block: Block, speed: UInt16) {
        let uuid = parseUUID()
        
        if let train = trains.first(where: { $0.id.uuid == uuid }) {
            assert(train.speed.requestedKph == speed, "Mismatching speed definition for train \(uuid)")
            assert(train.position == position, "Mismatching position definition for train \(uuid)")
            if block.train == nil {
                block.train = TrainInstance(train.id, .next)
            }
            block.train?.parts[position] = .locomotive
        } else {
            let train = Train(uuid: uuid)
            train.position = position
            train.routeStepIndex = route.steps.count
            train.speed = .init(kph: speed, decoderType: .MFX)
            train.routeId = route.id
            if block.train == nil {
                block.train = TrainInstance(train.id, .next)
            }
            block.train?.parts[position] = .locomotive
            trains.append(train)
        }
    }
        
    func parseWagon(position: Int, block: Block) {
        let uuid = parseUUID()

        if block.train == nil {
            block.train = TrainInstance(Identifier<Train>(uuid: uuid), .next)
        }
                        
        block.train?.parts[position] = .wagon
    }
        
    func parseFeedback(detected: Bool, newBlock: Bool, block: Block, feedbackIndex: Int, reverseOrder: Bool) {
        if newBlock {
            let f = Feedback("f\(block.id.uuid)\(feedbackIndex)")
            f.detected = detected
            // The LayoutAsserter is using the feedbacks in order in which they are added to the block
            if reverseOrder {
                block.add(f.id, at: 0)
            } else {
                block.add(f.id)
            }
            feedbacks.insert(f)
        } else {
            let feedback = block.feedbacks[feedbackIndex]
            let f = feedbacks.first(where: { $0.id == feedback.feedbackId })!
            assert(f.detected == detected, "The existing feedback does not match the `detected` defined in the ASCII representation")
            f.detected = detected
        }
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
            if let n = sp.matchesInteger() {
                reservedTrainNumber = String(n)
                sp.eat("<")
            } else {
                assertionFailure("Unexpected turnout identifier")
            }
        }
        
        let turnoutName = sp.matchString(["{", "(", ",", ">"])
        guard !turnoutName.isEmpty else {
            assertionFailure("Turnout must have its name specified")
            return
        }

        // Default values, if not specified
        var fromSocket = 0
        var toSocket = 1
        var state = Turnout.State.straight
        var type = Turnout.Category.singleRight
        
        // See if the type is defined
        if sp.matches("{") {
            let typeString = sp.matchString(["}"])
            guard !typeString.isEmpty else {
                assertionFailure("Turnout type must be specfied within { }")
                return
            }
            switch(typeString) {
            case "sl":
                type = .singleLeft
            case "sr":
                type = .singleRight
            case "tw":
                type = .threeWay
            case "ds":
                type = .doubleSlip
            case "ds2":
                type = .doubleSlip2
            default:
                assertionFailure("Invalid turnout type \(typeString)")
            }
            assert(sp.matches("}"), "Expecting closing '}' after type definition")
        }
        
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
            } else if sp.matches("b") {
                state = .branch
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
            assert(existingTurnout.reserved?.train.uuid == reservedTrainNumber, "Mismatching turnout reservation for turnout \(turnoutName)")
        } else {
            let turnout = Turnout(turnoutName, type: type, address: .init(0, .MM), state: state)
            if let reservedTrainNumber = reservedTrainNumber {
                turnout.reserved = .init(train: Identifier<Train>(uuid: reservedTrainNumber), sockets: .init(fromSocketId: fromSocket, toSocketId: toSocket))
            }
            layout.turnouts.append(turnout)
        }
        
        let step = Route.Step(turnoutId, Socket.turnout(turnoutId, socketId: fromSocket), Socket.turnout(turnoutId, socketId: toSocket))
        route.steps.append(step)
    }

}
