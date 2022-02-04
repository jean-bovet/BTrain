//
//  RouteResolver.swift
//  BTrain
//
//  Created by Jean Bovet on 2/2/22.
//

import Foundation

final class RouteResolver {
    
    let pf: PathFinder
    
    init(layout: Layout) {
        self.pf = PathFinder(layout: layout)
    }
    
    func resolve(route: Route) -> [Route.Step] {
        guard var previousStep = route.steps.first else {
            return []
        }
        for step in route.steps.dropFirst() {
            // TODO: should be able to reserve any block?
            let settings = PathFinderSettings(random: false, reservedBlockBehavior: .avoidReserved, consideringStoppingAtSiding: false, verbose: true)
            // TODO: do not specify the train but rather the set of blocks/turnouts to avoid
//            if let path = try pf.path(trainId: layout.trains[0].id, from: previousStep.blockId, destination: .init(step.blockId, direction: step.direction), direction: previousStep.direction, settings: settings) {
//                path.steps
//            }
        }
        return []
    }
}
