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

final class LayoutDiagnostic: ObservableObject {

    struct Options: OptionSet {
        let rawValue: Int

        static let lengths   = Options(rawValue: 1 << 0)
        static let duplicate = Options(rawValue: 1 << 1)
        static let orphaned  = Options(rawValue: 1 << 2)
        static let routes  = Options(rawValue: 1 << 3)

        static let skipLengths: Options = [.duplicate, .orphaned]
        static let all: Options = [.lengths, .duplicate, .orphaned, .routes]
    }

    let layout: Layout
        
    @Published var hasErrors = false
    @Published var errorCount = 0

    init(layout: Layout) {
        self.layout = layout
    }

    func automaticCheck() {
        do {
            errorCount = try check().count
            hasErrors = errorCount > 0
        } catch {
            BTLogger.error("Error checking the layout: \(error)")
            hasErrors = true
        }
    }
    
    func check(_ options: Options = Options.all) throws -> [DiagnosticError] {
        var errors = [DiagnosticError]()
                
        if options.contains(.duplicate) {
            checkForDuplicateFeedbacks(&errors)
            checkForDuplicateTurnouts(&errors)
            checkForDuplicateTrains(&errors)
            checkForDuplicateLocomotives(&errors)
            try checkForDuplicateBlocks(&errors)
        }
        
        if options.contains(.orphaned) {
            try checkForOrphanedElements(&errors)
        }
        
        if options.contains(.lengths) {
            checkForLengthAndDistance(&errors)
        }
        
        if options.contains(.routes) {
            checkRoutes(&errors)
        }
        
        errorCount = errors.count
        hasErrors = errorCount > 0
        
        return errors
    }
    
    func checkForDuplicateBlocks(_ errors: inout [DiagnosticError]) throws {
        let enabledBlocks = layout.blocks.filter({$0.enabled})
        var ids = Set<Identifier<Block>>()
        for block in enabledBlocks {
            if ids.contains(block.id) {
                errors.append(DiagnosticError.blockIdAlreadyExists(block: block))
            } else {
                ids.insert(block.id)
            }
        }

        var names = Set<String>()
        for block in enabledBlocks {
            if names.contains(block.name) {
                errors.append(DiagnosticError.blockNameAlreadyExists(block: block))
            } else {
                names.insert(block.name)
            }
        }

        var feedbacks = Set<Identifier<Feedback>>()
        for block in enabledBlocks {
            for blockFeedback in block.feedbacks {
                if feedbacks.contains(blockFeedback.feedbackId) {
                    guard let feedback = layout.feedback(for: blockFeedback.feedbackId) else {
                        throw LayoutError.feedbackNotFound(feedbackId: blockFeedback.feedbackId)
                    }
                    errors.append(DiagnosticError.blockDuplicateFeedback(block: block, feedback: feedback))
                }
                feedbacks.insert(blockFeedback.feedbackId)
            }
        }
    }

    func checkForDuplicateFeedbacks(_ errors: inout [DiagnosticError]) {
        var ids = Set<Identifier<Feedback>>()
        for f in layout.feedbacks {
            if ids.contains(f.id) {
                errors.append(DiagnosticError.feedbackIdAlreadyExists(feedback: f))
            } else {
                ids.insert(f.id)
            }
        }

        var names = Set<String>()
        for f in layout.feedbacks {
            if names.contains(f.name) {
                errors.append(DiagnosticError.feedbackNameAlreadyExists(feedback: f))
            } else {
                names.insert(f.name)
            }
        }

        var addresses = Set<String>()
        for f in layout.feedbacks {
            let key = "\(f.deviceID)-\(f.contactID)"
            if addresses.contains(key) {
                errors.append(DiagnosticError.feedbackDuplicateAddress(feedback: f))
            } else {
                addresses.insert(key)
            }
        }
    }

    func checkForDuplicateTurnouts(_ errors: inout [DiagnosticError]) {
        let enabledTurnouts = layout.turnouts.filter({ $0.enabled })
        
        var ids = Set<Identifier<Turnout>>()
        for turnout in enabledTurnouts {
            if ids.contains(turnout.id) {
                errors.append(DiagnosticError.turnoutIdAlreadyExists(turnout: turnout))
            } else {
                ids.insert(turnout.id)
            }
        }
        
        var names = Set<String>()
        for turnout in enabledTurnouts {
            if names.contains(turnout.name) {
                errors.append(DiagnosticError.turnoutNameAlreadyExists(turnout: turnout))
            } else {
                names.insert(turnout.name)
            }
        }

        var addresses = Set<CommandTurnoutAddress>()
        for turnout in enabledTurnouts {
            if addresses.contains(turnout.address) {
                errors.append(DiagnosticError.turnoutDuplicateAddress(turnout: turnout))
            }
            addresses.insert(turnout.address)
            if turnout.doubleAddress {
                if addresses.contains(turnout.address2) {
                    errors.append(DiagnosticError.turnoutDuplicateAddress(turnout: turnout))
                }
            }
            addresses.insert(turnout.address2)
        }
        
        for turnout in enabledTurnouts {
            if turnout.doubleAddress {
                if turnout.address == turnout.address2 {
                    errors.append(DiagnosticError.turnoutSameDoubleAddress(turnout: turnout))
                }
            }
        }
    }
    
    func checkForDuplicateTrains(_ errors: inout [DiagnosticError]) {
        let enabledTrains = layout.trains.elements.filter({$0.enabled})
        
        var ids = Set<Identifier<Train>>()
        for train in enabledTrains {
            if ids.contains(train.id) {
                errors.append(DiagnosticError.trainIdAlreadyExists(train: train))
            } else {
                ids.insert(train.id)
            }
        }
        
        var names = Set<String>()
        for train in enabledTrains {
            if names.contains(train.name) {
                errors.append(DiagnosticError.trainNameAlreadyExists(train: train))
            } else {
                names.insert(train.name)
            }
        }
        
        var locIds = Set<Identifier<Locomotive>>()
        for train in enabledTrains {
            guard let loc = train.locomotive else {
                continue
            }
            if locIds.contains(loc.id) {
                errors.append(DiagnosticError.trainLocomotiveAlreadyUsed(train: train, locomotive: loc))
            } else {
                locIds.insert(loc.id)
            }
        }
    }

    func checkForDuplicateLocomotives(_ errors: inout [DiagnosticError]) {
        let enabledLocs = layout.locomotives.filter({$0.enabled})
        var ids = Set<Identifier<Locomotive>>()
        for loc in enabledLocs {
            if ids.contains(loc.id) {
                errors.append(DiagnosticError.locIdAlreadyExists(loc: loc))
            } else {
                ids.insert(loc.id)
            }
        }
        
        var names = Set<String>()
        for loc in enabledLocs {
            if names.contains(loc.name) {
                errors.append(DiagnosticError.locNameAlreadyExists(loc: loc))
            } else {
                names.insert(loc.name)
            }
        }

        var addresses = Set<UInt32>()
        for loc in enabledLocs {
            let address = loc.address.actualAddress(for: loc.decoder)
            if addresses.contains(address) {
                errors.append(DiagnosticError.locDuplicateAddress(loc: loc))
            }
            addresses.insert(address)
        }
    }

    func checkForOrphanedElements(_ errors: inout [DiagnosticError]) throws {
        // Check for elements that are not linked together (orphaned sockets)
        for turnout in layout.turnouts {
            for socket in turnout.allSockets {
                if try layout.transition(from: socket) == nil {
                    let name: String
                    if let socketId = socket.socketId {
                        name = turnout.socketName(socketId)
                    } else {
                        name = "any"
                    }
                    errors.append(DiagnosticError.turnoutMissingTransition(turnout: turnout, socket: name))
                }
            }
        }
        
        for block in layout.blocks {
            for socket in block.allSockets {
                if try layout.transition(from: socket) == nil {
                    let name: String
                    if let socketId = socket.socketId {
                        name = block.socketName(socketId)
                    } else {
                        name = "any"
                    }
                    errors.append(DiagnosticError.blockMissingTransition(block: block, socket: name))
                }
            }
        }
        
        for transition in layout.transitions {
            for socket in [transition.a, transition.b] {
                if try layout.transition(from: socket) == nil {
                    errors.append(DiagnosticError.invalidTransition(transitionId: transition.id, socket: socket))
                }
            }
        }
        
        var feedbacks = Set<Identifier<Feedback>>()
        for feedback in layout.feedbacks {
            feedbacks.insert(feedback.id)
        }
        for block in layout.blocks {
            for bf in block.feedbacks {
                feedbacks.remove(bf.feedbackId)
            }
        }
        for unusedFeedback in feedbacks {
            if let fb = layout.feedback(for: unusedFeedback) {
                errors.append(DiagnosticError.unusedFeedback(feedback: fb))
            }
        }
        
        for train in layout.trains.elements {
            if train.locomotive == nil {
                errors.append(DiagnosticError.trainLocomotiveUndefined(train: train))
            }
        }
    }
    
    func checkForLengthAndDistance(_ errors: inout [DiagnosticError]) {
        for block in layout.blocks.filter({$0.enabled}) {
            guard let bl = block.length else {
                errors.append(DiagnosticError.blockMissingLength(block: block))
                continue
            }
            
            for bf in block.feedbacks {
                if let distance = bf.distance {
                    if distance < 0 || distance > bl {
                        errors.append(DiagnosticError.blockFeedbackInvalidDistance(block: block, feedback: bf))
                    }
                } else {
                    errors.append(DiagnosticError.blockFeedbackMissingDistance(block: block, feedbackId: bf.feedbackId))
                }
            }
        }
        
        for turnout in layout.turnouts.filter({$0.enabled}) {
            if turnout.length == nil {
                errors.append(DiagnosticError.turnoutMissingLength(turnout: turnout))
            }
        }
        for loc in layout.locomotives.filter({$0.enabled}) {
            if loc.length == nil {
                errors.append(DiagnosticError.locMissingLength(loc: loc))
            }
        }
        for train in layout.trains.elements.filter({$0.enabled}) {
            if train.wagonsLength == nil {
                errors.append(DiagnosticError.trainMissingLength(train: train))
            }
        }
    }
    
    func checkRoutes(_ errors: inout [DiagnosticError]) {
        var resolverErrors = [PathFinderResolver.ResolverError]()
        for route in layout.routes.filter({ $0.automatic == false }) {
            var resolvedRoutes = RouteResolver.ResolvedRoutes()
            checkRoute(route: route, &errors, resolverErrors: &resolverErrors, resolverPaths: &resolvedRoutes)
        }
    }
    
    func checkRoute(route: Route, _ errors: inout [DiagnosticError], resolverErrors: inout [PathFinderResolver.ResolverError], resolverPaths: inout RouteResolver.ResolvedRoutes) {
        let train = Train(id: Identifier<Train>(uuid: UUID().uuidString), name: "")
        let resolver = RouteResolver(layout: layout, train: train)
        do {
            try route.completePartialSteps(layout: layout, train: train)
            let result = try resolver.resolve(unresolvedPath: route.steps)
            switch result {
            case .success(let resolvedPaths):
                resolverPaths = resolvedPaths
                
            case .failure(let resolverError):
                resolverErrors.append(resolverError)
                errors.append(DiagnosticError.invalidRoute(route: route, error: "No path found"))
            }
        } catch {
            errors.append(DiagnosticError.invalidRoute(route: route, error: error.localizedDescription))
        }
    }
    
    func repair() {
        // Remove any transitions that are looping back to the same socket
        layout.transitions.removeAll { transition in
            transition.a == transition.b
        }
        
        // Remove any train that do not exist anymore
        for block in layout.blocks {
            if let trainId = block.trainInstance?.trainId {
                if layout.trains[trainId] == nil {
                    block.trainInstance = nil
                }
            }
            if let trainId = block.reservation?.trainId {
                if layout.trains[trainId] == nil {
                    block.reservation = nil
                }
            }
        }
    }
}
