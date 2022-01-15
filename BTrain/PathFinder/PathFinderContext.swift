//
//  PathFinderContext.swift
//  BTrain
//
//  Created by Jean Bovet on 1/14/22.
//

import Foundation

// This class is used to keep track of the various parameters during analysis
final class PathFinderContext {
    // Train associated with this path
    let trainId: Identifier<Train>

    // The destination block or nil if any station block can be chosen
    let toBlock: Block?
    
    // The maximum number of blocks in the path before
    // it overflows and the algorithm ends the analysis.
    // This is to avoid situation in which the algorithm
    // takes too long to return.
    let overflow: Int

    // Settings for the algorithm
    let settings: PathFinderSettings

    // The list of steps defining this path
    var steps = [Route.Step]()

    // The list of visited steps (block+direction),
    // used to ensure the algorithm does not
    // re-use a block and ends up in an infinite loop.
    var visitedSteps = [Route.Step]()
    
    init(trainId: Identifier<Train>, toBlock: Block?, overflow: Int, settings: PathFinderSettings) {
        self.trainId = trainId
        self.toBlock = toBlock
        self.overflow = overflow
        self.settings = settings
    }
    
    func hasVisited(_ step: Route.Step) -> Bool {
        return visitedSteps.contains { $0.same(step) }
    }

    var isOverflowing: Bool {
        return steps.count >= overflow
    }
    
    func print(_ msg: String) {
        if settings.verbose {
            BTLogger.debug(" \(msg)")
        }
    }
}
