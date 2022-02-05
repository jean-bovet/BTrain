//
//  RouteResolver.swift
//  BTrain
//
//  Created by Jean Bovet on 2/2/22.
//

import Foundation

final class RouteResolver {
    
    let layout: Layout
    let pf: PathFinder
    
    init(layout: Layout) {
        self.layout = layout
        self.pf = PathFinder(layout: layout)
    }
    
    func resolve(steps: ArraySlice<Route.Step>, trainId: Identifier<Train>? = nil) throws -> [Route.Step] {
        guard var previousStep = steps.first else {
            return []
        }
        var resolvedSteps = [previousStep]
        for step in steps.dropFirst() {
            guard let previousBlock = layout.block(for: previousStep.blockId) else {
                continue
            }
            guard let block = layout.block(for: step.blockId) else {
                continue
            }
            var settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReservedUntil(numberOfSteps: 0), consideringStoppingAtSiding: false, verbose: true)
            settings.includeTurnouts = true
            settings.ignoreDisabledBlocks = true
            settings.firstBlockShouldMatchDestination = true
            print("Resolving steps \(previousStep) to \(step)")
            // TODO: Note that the path finder might take a long time to resolve if the block to be found is in the last path to be evaluated. Should we switch
            // to breadth-first approach with depth 1, then 2 and so on?
            if let path = try pf.path(trainId: trainId, from: previousBlock, destination: .init(block.id, direction: step.direction!), direction: previousStep.direction!, settings: settings) {
                print("  Resolved to \(path.steps)")
                for turnoutStep in path.steps.filter({ $0.turnoutId != nil }) {
                    resolvedSteps.append(turnoutStep)
                }
            }
            resolvedSteps.append(step)
            previousStep = step
        }
        return resolvedSteps
    }
}

extension Layout {
    
    // TODO used? In LayoutParserTests I think - so move it there as a private extension
    func turnouts(from fromBlock: Block, to nextBlock: Block, direction: Direction) throws -> [Turnout] {
        let transitions = try transitions(from: fromBlock, to: nextBlock, direction: direction)
        var turnouts = [Turnout]()
        for transition in transitions {
            if let turnoutId = transition.b.turnout {
                guard let turnout = turnout(for: turnoutId) else {
                    fatalError("Unable to find turnout \(turnoutId)")
                }
                turnouts.append(turnout)
            }
        }
        return turnouts
    }

}
