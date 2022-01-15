//
//  PathFinderSettings.swift
//  BTrain
//
//  Created by Jean Bovet on 1/14/22.
//

import Foundation

struct PathFinderSettings {
    // True to generate a route at random, false otherwise.
    let random: Bool
    
    enum ReservedBlockBehavior {
        // Avoid all the reserved blocks
        case avoidReserved
        
        // Avoid the reserved blocks for the first
        // `numberOfSteps` of the route. After the route
        // has more steps than this, reserved block
        // will be taken into consideration. This option is
        // used in automatic routing when no particular destination
        // block is specified: BTrain will update the route if a
        // reserved block is found during the routing of the train.
        case avoidReservedUntil(numberOfSteps: Int)
    }
    
    let reservedBlockBehavior: ReservedBlockBehavior
            
    let verbose: Bool
}
