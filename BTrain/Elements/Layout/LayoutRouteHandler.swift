// Copyright 2021 Jean Bovet
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

protocol LayoutRouteHandling {
    
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, toBlockId: Identifier<Block>?) throws
    func stop(routeID: Identifier<Route>, trainID: Identifier<Train>) throws
    
}

extension Layout: LayoutRouteHandling {
        
    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, toBlockId: Identifier<Block>? = nil) throws {
        try routeHandling.start(routeID: routeID, trainID: trainID, toBlockId: toBlockId)
    }
    
    func stop(routeID: Identifier<Route>, trainID: Identifier<Train>) throws {
        try routeHandling.stop(routeID: routeID, trainID: trainID)
    }
    
}

final class LayoutRouteHandler: LayoutRouteHandling {
    
    private let layout: Layout
    private let trainController: LayoutTrainHandling
    
    init(layout: Layout, trainController: LayoutTrainHandling) {
        self.layout = layout
        self.trainController = trainController
    }

    func start(routeID: Identifier<Route>, trainID: Identifier<Train>, toBlockId: Identifier<Block>?) throws {
        guard let route = layout.route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }
        
        guard let train = layout.mutableTrain(for: trainID) else {
            throw LayoutError.trainNotFound(trainId: trainID)
        }
        
        // Ensure the automatic route associated with the train is updated
        if route.automatic {
            // Remember the destination block
            route.destinationBlock = toBlockId
            try layout.updateAutomaticRoute(for: trainID, toBlockId: toBlockId)
        }

        // Ensure the route is not empty
        guard !route.steps.isEmpty else {
            throw LayoutError.noSteps(routeId: routeID)
        }

        // Set the route to the train
        train.routeId = routeID

        // Check to make sure the train is somewhere along the route
        train.routeIndex = -1
        for (index, step) in route.steps.enumerated() {
            if train.blockId == step.blockId {
                train.routeIndex = index
                break
            }
        }
                             
        guard train.routeIndex >= 0 else {
            throw LayoutError.trainNotFoundInRoute(train: train, route: route)            
        }

        guard let blockId = train.blockId else {
            throw LayoutError.trainNotAssignedToABlock(trainId: train.id)
        }
        
        guard let block = layout.block(for: blockId), block.train != nil else {
            throw LayoutError.trainNotFoundInBlock(blockId: blockId)
        }
        
        train.speed = 0
                
        route.enabled = true
    }

    func stop(routeID: Identifier<Route>, trainID: Identifier<Train>) throws {
        guard let route = layout.route(for: routeID, trainId: trainID) else {
            throw LayoutError.routeNotFound(routeId: routeID)
        }

        route.enabled = false
    }
    
}
