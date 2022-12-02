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

@testable import BTrain
import Foundation

final class LayoutRouteParser {
    let layout: LayoutParser.ParsedLayout

    final class ParsedRoute {
        var routeId: Identifier<Route>!
        var resolvedSteps = [ResolvedRouteItem]()
    }

    let route = ParsedRoute()

    let sp: LayoutStringParser

    let resolver: LayoutParserResolver
    
    /// Temporary variable holding the train being parsed. It is created when a wagon is first encountered
    private var parsedTrain: Train?

    enum ParserError: Error {
        case parserError(message: String)
    }

    init(ls: String, id _: String, layout: LayoutParser.ParsedLayout, resolver: LayoutParserResolver) {
        sp = LayoutStringParser(ls: ls)
        self.layout = layout
        self.resolver = resolver
    }

    func parseRouteName() throws {
        let routeName = sp.matchString(":")
        guard !routeName.isEmpty else {
            throw ParserError.parserError(message: "Route name must be specified for each route")
        }
        route.routeId = Identifier<Route>(uuid: routeName)
        sp.eat(":")
    }

    func parse() throws {
        try parseRouteName()

        while sp.more {
            if sp.matches("!{") {
                try parseBlock(category: .station, direction: .previous)
            } else if sp.matches("{") {
                try parseBlock(category: .station, direction: .next)
            } else if sp.matches("![") {
                try parseBlock(category: .free, direction: .previous)
            } else if sp.matches("|[") {
                try parseBlock(category: .sidingPrevious, direction: .next)
            } else if sp.matches("[") {
                try parseBlock(category: .free, direction: .next)
            } else if sp.matches("<") {
                try parseTurnouts()
            } else if sp.matches(" ") {
                // Ignore white space
            } else {
                throw ParserError.parserError(message: "Unexpected character '\(sp.c)' found while parsing block definition")
            }
        }

        addTransitions()
    }

    func addTransitions() {
        for index in 0 ..< route.resolvedSteps.count {
            if index + 1 == route.resolvedSteps.count {
                // We have reached the last step, there is no transitions out of it
                continue
            }

            let step = route.resolvedSteps[index]
            let nextStep = route.resolvedSteps[index + 1]

            layout.link(from: step.exitSocket,
                        to: nextStep.entrySocket)
        }
    }

    func parseBlock(category: Block.Category, direction: Direction) throws {
        let block: Block
        let newBlock: Bool

        let blockHeader = try parseBlockHeader(type: category, direction: direction)

        // Parse the optional digit that indicates a reference to an existing block
        // Example: { ≏ ≏ } [[ ≏ 🟢􀼮 ≏ ]] [[ ≏ ≏ ]] {b0 ≏ ≏ }
        if let blockName = blockHeader.blockName {
            let blockID = resolver.blockId(forBlockName: blockName)
            if let existingBlock = layout.blocks.first(where: { $0.id == blockID }) {
                block = existingBlock
                assert(block.category == category, "The existing block \(blockID) does not match the type defined in the ASCII representation")
                assert(block.reservation?.trainId == blockHeader.reserved?.trainId, "The existing block \(blockID) does not match the reserved type defined in the ASCII representation")
                newBlock = false
            } else {
                block = Block(name: blockID.uuid)
                block.category = category
                block.reservation = blockHeader.reserved
                newBlock = true
            }
        } else {
            // Note: use a UUID that is using the number of blocks created so far
            // so the UUID is easy to unit test
            block = Block(name: String(route.resolvedSteps.count))
            block.category = category
            block.reservation = blockHeader.reserved
            newBlock = true
        }

        if direction == .previous {
            let index = sp.index
            let numberOfFeedbacks = try parseNumberOfFeedbacks(block: block, newBlock: newBlock, type: category)
            sp.index = index
            try parseBlockContent(block: block, directionInBlock: direction, newBlock: newBlock, type: category, numberOfFeedbacks: numberOfFeedbacks)
        } else {
            try parseBlockContent(block: block, directionInBlock: direction, newBlock: newBlock, type: category, numberOfFeedbacks: nil)
        }

        layout.blocks.insert(block)
        route.resolvedSteps.append(.block(.init(block: block, direction: direction)))
    }

    enum BlockContentType {
        case locomotive(attributes: TrainAttributes)
        case wagon(uuid: String)

        case endStation(reserved: Bool)
        case endFreeOrSidingPrevious(reserved: Bool)
        case endFreeOrSidingNext(reserved: Bool)

        case feedback(detected: Bool)
    }

    typealias BlockContentCallback = (BlockContentType) -> Void

    func parseNumberOfFeedbacks(block: Block, newBlock: Bool, type: Block.Category) throws -> Int {
        var currentFeedbackIndex = 0
        try parseBlockContent(block: block, newBlock: newBlock, type: type) { contentType in
            switch contentType {
            case .locomotive:
                break
            case .wagon:
                break
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

    func parseBlockContent(block: Block, directionInBlock: Direction, newBlock: Bool, type: Block.Category, numberOfFeedbacks: Int?) throws {
        var currentFeedbackIndex = 0
        try parseBlockContent(block: block, newBlock: newBlock, type: type) { contentType in
            let feedbackIndex: Int
            let position: Int
            if let numberOfFeedbacks = numberOfFeedbacks {
                feedbackIndex = numberOfFeedbacks - currentFeedbackIndex - 1
                position = numberOfFeedbacks - currentFeedbackIndex
            } else {
                feedbackIndex = currentFeedbackIndex
                position = currentFeedbackIndex
            }

            switch contentType {
            case .locomotive(let attributes):
                createTrain(position: position, block: block, directionInBlock: directionInBlock, attributes: attributes)

            case .wagon(let uuid):
                parseWagon(position: position, block: block, directionInBlock: directionInBlock, uuid: uuid)

            case let .endStation(reserved: reserved):
                assert(type == .station, "Expected end of station block \(reserved)")

            case let .endFreeOrSidingPrevious(reserved: reserved):
                assert(type == .free || type == .sidingPrevious, "Expected end of .free or .sidingPrevious track block \(reserved)")

            case let .endFreeOrSidingNext(reserved: reserved):
                assert(type == .free, "Expected end of .free (but soon to be .sidingNext) track block \(reserved)")
                block.category = .sidingNext // Change to sidingNext here because that's only when we know if it is one!

            case let .feedback(detected: detected):
                assert(feedbackIndex >= 0, "Invalid feedback index \(feedbackIndex)")
                parseFeedback(detected: detected, newBlock: newBlock, block: block, feedbackIndex: feedbackIndex, reverseOrder: numberOfFeedbacks != nil)
                currentFeedbackIndex += 1
            }
        }
    }

    func parseBlockContent(block _: Block, newBlock _: Bool, type _: Block.Category, callback: BlockContentCallback) throws {
        var parsingBlock = true
        while sp.more, parsingBlock {
            if let attributes = parseTrainAttributes() {
                callback(.locomotive(attributes: attributes))
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
            } else if sp.matches("􀼯") {
                callback(.wagon(uuid: parseUUID()))
            } else {
                throw ParserError.parserError(message: "Unknown character '\(sp.c)'")
            }
        }
    }

    struct BlockHeader {
        var blockName: String?
        var reserved: Reservation?
    }

    func parseBlockHeader(type: Block.Category, direction: Direction) throws -> BlockHeader {
        var header = BlockHeader()

        var reservedTrainNumber: String?
        if sp.matches("r") {
            if let n = sp.matchesInteger() {
                reservedTrainNumber = String(n)
            } else {
                throw ParserError.parserError(message: "Unexpected train number reservation")
            }
        }

        var reserved = false
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
                throw ParserError.parserError(message: "A reserved block must have a reservation train number specified!")
            }
        }

        let blockName = sp.matchString()
        if blockName.isEmpty {
            throw ParserError.parserError(message: "Expecting a block name")
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
            uuid = route.routeId.uuid
        }
        return uuid
    }

    struct TrainAttributes {
        let speed: UInt16
        let direction: Direction
        let allowedDirection: Locomotive.AllowedDirection
        let uuid: String
    }
    
    // <Speed Symbol>[speed value][direction in block]􀼮[allowed direction symbol ⟷]<identifier>
    // 🟡17!􀼮⟷1
    // 🟡17!􀼮1
    // 🟡17􀼮1
    // 🟡􀼮1
    func parseTrainAttributes() -> TrainAttributes? {
        let defaultSpeed: UInt16
        if sp.matches("🔴") {
            defaultSpeed = 0
        } else if sp.matches("🟡") {
            defaultSpeed = LayoutFactory.DefaultBrakingSpeed
        } else if sp.matches("🟢") {
            defaultSpeed = LayoutFactory.DefaultMaximumSpeed
        } else if sp.matches("🔵") {
            defaultSpeed = LayoutFactory.DefaultLimitedSpeed
        } else {
            return nil
        }
        
        let speed: SpeedKph
        if let specifiedSpeed = sp.matchesInteger() {
            speed = SpeedKph(specifiedSpeed)
        } else {
            speed = defaultSpeed
        }

        let direction: Direction
        if sp.matches("!") {
            direction = .previous
        } else {
            direction = .next
        }
        _ = sp.matches("􀼮")

        let allowedDirection: Locomotive.AllowedDirection
        if sp.matches("⟷") {
            allowedDirection = .any
        } else {
            allowedDirection = .forward
        }

        let uuid = parseUUID()

        return .init(speed: speed, direction: direction, allowedDirection: allowedDirection, uuid: uuid)
    }
    
    func createTrain(position: Int, block: Block, directionInBlock: Direction, attributes: TrainAttributes) {
        if let train = layout.trains.first(where: { $0.id.uuid == attributes.uuid }) {
            let loc = train.locomotive!
            assert(loc.speed.requestedKph == attributes.speed, "Mismatching speed definition for train \(attributes.uuid)")
            assert(train.position.front?.index == position, "Mismatching position definition for train \(attributes.uuid)")
            if block.trainInstance == nil {
                block.trainInstance = TrainInstance(train.id, .next)
            }
            block.trainInstance?.parts[position] = .locomotive
        } else {
            let loc = Locomotive(uuid: attributes.uuid)
            loc.speed = .init(kph: attributes.speed, decoderType: .MFX)
            loc.allowedDirections = attributes.allowedDirection
            
            let train: Train
            let distance = resolver.distance(forFeedbackAtPosition: position, blockId: block.id, directionInBlock: attributes.direction)
            if let parsedTrain = parsedTrain {
                train = parsedTrain
                train.position.front = .init(blockId: block.id, index: position, distance: distance)
                self.parsedTrain = nil
            } else {
                train = Train(uuid: attributes.uuid)
                train.position = .both(blockId: block.id, frontIndex: position, frontDistance: distance, backIndex: position, backDistance: distance)
            }
            
            train.locomotive = loc
            train.routeStepIndex = route.resolvedSteps.count
            train.routeId = route.routeId
            if block.trainInstance == nil {
                block.trainInstance = TrainInstance(train.id, .next)
            }
            block.trainInstance?.parts[position] = .locomotive
            layout.trains.insert(train)
        }
    }
        
    func parseWagon(position: Int, block: Block, directionInBlock: Direction, uuid: String) {
        if block.trainInstance == nil {
            block.trainInstance = TrainInstance(Identifier<Train>(uuid: uuid), .next)
        }
        if let train = layout.trains.first(where: { $0.id.uuid == uuid }) {
            let distance = resolver.distance(forFeedbackAtPosition: position, blockId: block.id, directionInBlock: directionInBlock)
            train.position.back = .init(blockId: block.id, index: position, distance: distance)
        } else {
            // If a wagon is first detected, the train might not yet be created.
            // Create the train and remembers the back position of it.
            if parsedTrain == nil {
                parsedTrain = Train(uuid: uuid)
                let distance = resolver.distance(forFeedbackAtPosition: position, blockId: block.id, directionInBlock: directionInBlock)
                parsedTrain?.position.back = .init(blockId: block.id, index: position, distance: distance)
            }
        }
        
        block.trainInstance?.parts[position] = .wagon
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
            layout.feedbacks.insert(f)
        } else {
            let feedback = block.feedbacks[feedbackIndex]
            let f = layout.feedbacks.first(where: { $0.id == feedback.feedbackId })!
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
    func parseTurnouts() throws {
        var reservedTrainNumber: String?
        if sp.matches("r") {
            if let n = sp.matchesInteger() {
                reservedTrainNumber = String(n)
                sp.eat("<")
            } else {
                throw ParserError.parserError(message: "Unexpected turnout identifier")
            }
        }

        let turnoutName = sp.matchString(["{", "(", ",", ">"])
        guard !turnoutName.isEmpty else {
            throw ParserError.parserError(message: "Turnout must have its name specified")
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
                throw ParserError.parserError(message: "Turnout type must be specified within { }")
            }
            switch typeString {
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
                throw ParserError.parserError(message: "Invalid turnout type \(typeString)")
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
                throw ParserError.parserError(message: "Invalid turnout state")
            }
        }

        assert(sp.matches(">"), "Expecting closing turnout character")

        if reservedTrainNumber != nil {
            assert(sp.matches(">"), "Expecting closing reserved turnout character")
        }

        let turnoutId = resolver.turnoutId(forTurnoutName: turnoutName)
        let turnout: Turnout
        if let existingTurnout = layout.turnouts.first(where: { $0.id == turnoutId }) {
            assert(existingTurnout.actualState == state, "Mismatching turnout state for turnout \(turnoutName)")
            assert(existingTurnout.reserved?.train.uuid == reservedTrainNumber, "Mismatching turnout reservation for turnout \(turnoutName)")
            turnout = existingTurnout
        } else {
            turnout = Turnout(id: turnoutId)
            turnout.category = type
            turnout.actualState = state
            if let reservedTrainNumber = reservedTrainNumber {
                turnout.reserved = .init(train: Identifier<Train>(uuid: reservedTrainNumber), sockets: .init(fromSocketId: fromSocket, toSocketId: toSocket))
            }
            layout.turnouts.insert(turnout)
        }

        route.resolvedSteps.append(.turnout(.init(turnout: turnout, entrySocketId: fromSocket, exitSocketId: toSocket)))
    }
}
