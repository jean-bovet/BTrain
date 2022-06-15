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

final class TrainController: TrainControlling {

    let train: Train
    let layout: Layout
    let layoutController: LayoutController
    let reservation: LayoutReservation

    var currentBlock: Block
    var trainInstance: TrainInstance

    var id: String {
        train.id.uuid
    }
    
    var mode: StateMachine.TrainMode {
        train.scheduling
    }
    
    var state: StateMachine.TrainState {
        get {
            train.state
        }
        set {
            train.state = newValue
        }
    }
    
    var speed: TrainSpeed.UnitKph {
        get {
            train.speed.actualKph
        }
        set {
            train.speed.actualKph = newValue
        }
    }
    
    var brakeFeedbackActivated: Bool {
        guard let brakeFeedback = currentBlock.brakeFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: brakeFeedback)
    }
    
    var stopFeedbackActivated: Bool {
        guard let stopFeedback = currentBlock.stopFeedback(for: trainInstance.direction) else {
            return false
        }
        
        return isFeedbackTriggered(layout: layout, train: train, feedbackId: stopFeedback)
    }
    
    var startedRouteIndex: Int {
        get {
            train.startRouteIndex ?? 0
        }
        set {
            train.startRouteIndex = newValue
        }
    }
    
    var currentRouteIndex: Int {
        train.routeStepIndex
    }
    
    var endRouteIndex: Int {
        guard let route = layout.route(for: train.routeId, trainId: train.id) else {
            fatalError()
        }
        return route.lastStepIndex
    }
    
    var atStation: Bool {
        guard let block = layout.block(for: train.blockId) else {
            return false
        }
        return block.category == .station
    }
    
    init(train: Train, layout: Layout, currentBlock: Block, trainInstance: TrainInstance, layoutController: LayoutController, reservation: LayoutReservation) {
        self.train = train
        self.layout = layout
        self.currentBlock = currentBlock
        self.trainInstance = trainInstance
        self.layoutController = layoutController
        self.reservation = reservation
    }
    
    func reservedBlocksLengthEnough(forSpeed speed: TrainSpeed.UnitKph) -> Bool {
        return reservation.isBrakingDistanceRespected(train: train, speed: speed)
    }
    
    func updatePosition(with feedback: Feedback) -> Bool {
        // TODO: throw all the try!
        if try! moveInsideBlock() {
            return true
        } else if try! moveToNextBlock() {
            return true
        }
        return false
    }
    
    func updateReservedBlocksSettledLength(with turnout: Turnout) -> Bool {
        let newSettledLength = train.leading.computeSettledDistance()
        if newSettledLength != train.leading.settledDistance {
            train.leading.settledDistance = newSettledLength
            return true
        } else {
            return false
        }
    }
    
    func updateOccupiedAndReservedBlocks() -> Bool {
        return updateReservedBlocks()
    }
    
    func updateReservedBlocks() -> Bool {
        if try! reservation.updateReservedBlocks(train: train) == .success {
            return true
        } else {
            return false
        }
    }
    
    func removeReservedBlocks() -> Bool {
        return try! reservation.removeLeadingBlocks(train: train)
    }
    
    func adjustSpeed() {
        layoutController.setTrainSpeed(train, 0)
    }
 
    // MARK: --
    
    private func isFeedbackTriggered(layout: Layout, train: Train, feedbackId: Identifier<Feedback>) -> Bool {
        for bf in currentBlock.feedbacks {
            guard let f = layout.feedback(for: bf.feedbackId) else {
                continue
            }
            
            if feedbackId == f.id && f.detected {
                return true
            }
        }
        return false
    }

    func moveInsideBlock() throws -> Bool {
        // Iterate over all the feedbacks of the block and react to those who are triggered (aka detected)
        for (index, feedback) in currentBlock.feedbacks.enumerated() {
            guard let f = layout.feedback(for: feedback.feedbackId), f.detected else {
                continue
            }
            
            let position = layout.newPosition(forTrain: train, enabledFeedbackIndex: index, direction: trainInstance.direction)
            
            guard train.position != position else {
                continue
            }
            
            // Note: do not remove the leading blocks as this will be taken care below by the `reserveLeadingBlocks` method.
            // This is important because the reserveLeadingBlocks method needs to remember the previously reserved turnouts
            // in order to avoid re-activating them each time unnecessarily.
            try layoutController.setTrainPosition(train, position, removeLeadingBlocks: false)
            
            BTLogger.router.debug("\(self.train, privacy: .public): moved to position \(self.train.position) in \(self.currentBlock.name, privacy: .public), direction \(self.trainInstance.direction)")
                        
            return true
        }
        
        return false
    }
    
    func moveToNextBlock() throws -> Bool {
        // Find out what is the entry feedback for the next block
        let entryFeedback = try layout.entryFeedback(for: train)
        
        guard let entryFeedback = entryFeedback, entryFeedback.feedback.detected else {
            // The entry feedback is not yet detected, nothing more to do
            return false
        }
        
        guard let position = entryFeedback.block.indexOfTrain(forFeedback: entryFeedback.feedback.id, direction: entryFeedback.direction) else {
            throw LayoutError.feedbackNotFound(feedbackId: entryFeedback.feedback.id)
        }
        
        BTLogger.router.debug("\(self.train, privacy: .public): enters block \(entryFeedback.block, privacy: .public) at position \(position), direction \(entryFeedback.direction)")

        // Note: do not remove the leading blocks as this will be taken care below by the `reserveLeadingBlocks` method.
        // This is important because the reserveLeadingBlocks method needs to remember the previously reserved turnouts
        // in order to avoid re-activating them each time unnecessarily.
        try layoutController.setTrainToBlock(train, entryFeedback.block.id, position: .custom(value: position), direction: entryFeedback.direction, routeIndex: train.routeStepIndex + 1, removeLeadingBlocks: false)
        
        guard let newBlock = layout.block(for: entryFeedback.block.id) else {
            throw LayoutError.blockNotFound(blockId: entryFeedback.block.id)
        }
        
        currentBlock = newBlock
        
        guard let newTrainInstance = newBlock.train else {
            throw LayoutError.trainNotFoundInBlock(blockId: newBlock.id)
        }
        
        trainInstance = newTrainInstance
                
        return true
    }
}
