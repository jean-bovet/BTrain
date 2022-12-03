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

/**
  This class handles the reservation of blocks for the train.

  There are two types of reserved blocks:
  - **Leading** Blocks: the blocks that are in front of the train (in the direction of travel). These blocks are reserved in order for the train to be able to move into them safely without risking a collision with another train..
  - **Occupied** Blocks: the blocks that are occupied by the train itself (locomotive and cars included). These blocks are usually behind the train in the opposite direction of travel,
  unless the locomotive is pushing the wagons, in which case they are in front of the locomotive.

  ````
                    Train (Locomotive + 2 cars)

                          ┌────┐  ┌────┐
                          │ C2 │  │ C1 │▶
                          └────┘  └────┘

 ┌───────┐  ┌───────┐  ╔═══════╗  ╔═══════╗  ┏━━━━━━━┓  ┏━━━━━━━┓
 │  B5   │──│  B4   │──║  B3   ║──║  B2   ║──┃ | B1  ┃──┃  B0   ┃
 └───────┘  └───────┘  ╚═══════╝  ╚═══════╝  ┗━━━━━━━┛  ┗━━━━━━━┛

      Free Blocks        Occupied Blocks        Heading Blocks

                    Train (Locomotive + 2 cars)

                          ┌────┐  ┌────┐
                          │ C2 │  │ C1 │◀
                          └────┘  └────┘

 ┏━━━━━━━┓  ┏━━━━━━━┓  ╔═══════╗  ╔═══════╗  ┌───────┐  ┌───────┐
 ┃  B5   ┃──┃  B4   ┃──║ B3 |  ║──║  B2   ║──│  B1   │──│  B0   │
 ┗━━━━━━━┛  ┗━━━━━━━┛  ╚═══════╝  ╚═══════╝  └───────┘  └───────┘

    Heading Blocks       Occupied Blocks       Free Blocks
  ````
 */
final class LayoutReservation {
    let layout: Layout
    weak var executor: LayoutController?
    let verbose: Bool

    // Internal structure used to hold information
    // about an upcoming turnout reservation
    internal struct TurnoutReservation {
        let turnout: Turnout
        let state: Turnout.State
        let sockets: Turnout.Reservation.Sockets
    }

    /// Internal structure used to remember which turnout was
    /// reserved and for which state so it is not re-activated unnecessarily.
    internal struct TurnoutActivation: Hashable {
        let turnout: Turnout
        let state: Turnout.State

        init(turnout: Turnout) {
            self.turnout = turnout
            state = turnout.requestedState
        }
    }

    init(layout: Layout, executor: LayoutController, verbose: Bool) {
        self.layout = layout
        self.executor = executor
        self.verbose = verbose
    }

    /// Result of updating the reserved blocks
    enum Result {
        /// Could not reserve the blocks
        case failure

        /// Successfully reserved the blocks
        case success

        /// Successfully reserved the same blocks
        /// as previously reserved (no change)
        case successAndUnchanged
    }

    /// Update the leading and occupied blocks for the specified train.
    /// - Parameter train: the train
    /// - Returns: the result of the operation
    func updateReservedBlocks(train: Train) throws -> Result {
        let previousLeadingItems = train.leading.items
        let previousOccupiedItems = train.occupied.items

        // Remember all the turnouts that have been already reserved so we don't re-activate
        // them again when reserving the blocks in this flow.
        let reservedTurnouts = Set<TurnoutActivation>(train.leading.turnouts.map { TurnoutActivation(turnout: $0) })

        // Remove the train from all the elements
        try freeElements(train: train)

        // Reserve and set the train and its wagon(s) using the necessary number of
        // elements (turnouts and blocks)
        try occupyBlocksWith(train: train)

        // Reserve the number of leading blocks necessary
        if try reserveLeadingBlocks(train: train, reservedTurnouts: reservedTurnouts) {
            train.leading.updateSettledDistance()
            // Return the result by determining if the leading or occupied items have changed
            if previousLeadingItems != train.leading.items || previousOccupiedItems != train.occupied.items {
                return .success
            } else {
                return .successAndUnchanged
            }
        } else {
            train.leading.settledDistance = 0
            return .failure
        }
    }

    /// Removes the reservation for the leading blocks of the specified train but keep the occupied blocks intact (that the train actually occupies).
    ///
    /// - Parameter train: the train
    //TODO: can't we just rely on the lead blocks of the train to remove them? Instead of removing all the elements?
    @discardableResult
    func removeLeadingBlocks(train: Train) throws -> Bool {
        let previousLeadingItems = train.leading.items

        // Remove the train from all the elements
        try freeElements(train: train)

        // Reserve and set the train and its wagon(s) using the necessary number of
        // elements (turnouts and blocks)
        try occupyBlocksWith(train: train)

        return previousLeadingItems != train.leading.items
    }

    private func reserveLeadingBlocks(train: Train, reservedTurnouts: Set<TurnoutActivation>) throws -> Bool {
        // The route must be defined and not be empty
        guard let route = layout.route(for: train.routeId, trainId: train.id), !route.steps.isEmpty else {
            debug("Cannot reserve leading blocks because route is empty")
            return false
        }

        // We are going to iterate over all the remaining steps of the route until we
        // either (1) reach the end of the route or (2) we have reserved enough blocks.
        let startReservationIndex = min(route.lastStepIndex, train.routeStepIndex)
        let stepsToReserve = route.steps[startReservationIndex ... route.lastStepIndex]

        // First of all, resolve the route to discover all non-specified turnouts and blocks
        let result = try RouteResolver(layout: layout, train: train).resolve(unresolvedPath: stepsToReserve.map { $0 })
        switch result {
        case let .success(resolvedPaths):
            if let resolvedPath = resolvedPaths.randomElement() {
                assert(resolvedPath.count >= stepsToReserve.count)
                return try reserveSteps(train: train, route: route, resolvedSteps: resolvedPath, reservedTurnouts: reservedTurnouts)
            } else {
                return false
            }

        case .failure:
            return false
        }
    }

    private func reserveSteps(train: Train, route: Route, resolvedSteps: [ResolvedRouteItem], reservedTurnouts: Set<TurnoutActivation>) throws -> Bool {
        // Variable keeping track of the number of leading blocks that have been reserved.
        // At least one block must have been reserved to consider this function successful.
        // Note: blocks that are reserved for the train and its wagons do not count against that count.
        var numberOfLeadingBlocksReserved = 0

        // Remember the turnouts between two blocks. This is because we are going to reserve
        // the turnouts between two blocks only when we can guarantee that the destination block
        // can be indeed reserved - otherwise we end up with a bunch of turnouts that are reserved
        // but lead to a non-reserved block.
        var turnouts = [TurnoutReservation]()

        // Remember the transitions between two blocks. This is because we are going to reserve
        // the turnouts between two blocks only when we can guarantee that the destination block
        // can be indeed reserved - otherwise we end up with a bunch of turnouts that are reserved
        // but lead to a non-reserved block.
        var transitions = [ITransition]()

        // Remember the previous step so we can determine the transitions between two elements.
        var previousStep: ResolvedRouteItem?

        // Iterate over all the resolved steps
        for step in resolvedSteps {
            try rememberTransitions(from: previousStep, to: step, transitions: &transitions)

            switch step {
            case let .block(stepBlock):
                if try !reserveBlock(block: stepBlock.block, direction: stepBlock.direction, train: train, route: route, reservedTurnouts: reservedTurnouts, numberOfLeadingBlocksReserved: &numberOfLeadingBlocksReserved, turnouts: &turnouts, transitions: &transitions) {
                    return numberOfLeadingBlocksReserved > 0
                }

            case let .turnout(stepTurnout):
                if !rememberTurnoutToReserve(turnout: stepTurnout.turnout, train: train, step: stepTurnout, numberOfLeadingBlocksReserved: &numberOfLeadingBlocksReserved, turnouts: &turnouts) {
                    return numberOfLeadingBlocksReserved > 0
                }
            }

            // Stop once we have reached the maximum number of leading blocks to reserve
            if numberOfLeadingBlocksReserved >= train.maxNumberOfLeadingReservedBlocks {
                break
            }

            previousStep = step
        }

        return numberOfLeadingBlocksReserved > 0
    }

    private func reserveBlock(block: Block, direction: Direction, train: Train, route: Route, reservedTurnouts: Set<TurnoutActivation>, numberOfLeadingBlocksReserved: inout Int, turnouts: inout [TurnoutReservation], transitions: inout [ITransition]) throws -> Bool {
        if block.isOccupied(by: train.id) {
            // The block is already reserved and contains a portion of the train
            // Note: we are not incrementing `numberOfLeadingBlocksReserved` because
            // an occupied block does not count as a "leading" block; it is occupied because
            // the train (or portion of it) occupies it.
            debug("Block \(block.name) is already reserved (and occupied) for \(train.name), nothing more to do.")
        } else {
            guard block.canBeReserved(withTrain: train, direction: direction) else {
                return false
            }

            // Now that the block can be reserved, reserve all the turnouts leading to
            // that block, including setting the appropriate state to each turnout
            for tr in turnouts {
                try reserveTurnout(reservation: tr, train: train, reservedTurnouts: reservedTurnouts)
            }
            turnouts.removeAll()

            // Reserve all the transitions
            for transition in transitions {
                guard transition.reserved == nil || (transition.reserved == train.id && transition.train == train.id) else {
                    throw LayoutError.transitionAlreadyReserved(transition: transition)
                }
                debug("Reserving transition \(transition) for \(train.description(layout))")
                transition.reserved = train.id
            }
            transitions.removeAll()

            // Now reserve the block
            let reservation = Reservation(trainId: train.id, direction: direction)
            block.reservation = reservation
            train.leading.append(block)
            numberOfLeadingBlocksReserved += 1
            debug("Reserving block \(block.name) for \(reservation)")
        }

        // Stop reserving as soon as a block that is going to
        // stop the train is detected. That way, the train stops
        // without reserving any block ahead and upon restarting,
        // it will reserve what it needs in front of it.
        guard !train.hasReachedStationOrDestination(route, block) else {
            return false
        }

        return true
    }

    private func reserveTurnout(reservation: TurnoutReservation, train: Train, reservedTurnouts: Set<TurnoutActivation>) throws {
        let turnout = reservation.turnout
        guard turnout.canBeReserved else {
            throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
        }

        turnout.requestedState = reservation.state
        turnout.reserved = .init(train: train.id, sockets: reservation.sockets)
        train.leading.append(turnout)

        if reservedTurnouts.contains(TurnoutActivation(turnout: turnout)) {
            // Do not request a turnout state change to the Digital Controller if the turnout is settled (which means it has already the state
            // requested) AND it has already been reserved. This is to avoid flooding the Digital Controller with unnecessary turnout requests
            // because this method is called frequently (when a train moves within a block or to a next block).
            BTLogger.reservation.debug("\(train, privacy: .public): do not activate state \(turnout.requestedState, privacy: .public) for turnout \(turnout.name, privacy: .public) because it was already activated")
        } else {
            BTLogger.reservation.debug("\(train, privacy: .public): request state \(turnout.requestedState, privacy: .public) for turnout \(turnout.name, privacy: .public)")
            executor?.sendTurnoutState(turnout: turnout) { completed in
                BTLogger.reservation.debug("\(train, privacy: .public): request state \(turnout.requestedState, privacy: .public) for turnout \(turnout.name, privacy: .public) [command executed: \(completed)]")
            }
        }
    }

    private func rememberTurnoutToReserve(turnout: Turnout, train: Train, step: ResolvedRouteItemTurnout, numberOfLeadingBlocksReserved _: inout Int, turnouts: inout [TurnoutReservation]) -> Bool {
        let fromSocketId = step.entrySocketId
        let toSocketId = step.exitSocketId
        let state = turnout.state(fromSocket: fromSocketId, toSocket: toSocketId)

        if turnout.isOccupied(by: train.id) {
            // The turnout is already reserved and contains a portion of the train
            debug("Turnout \(turnout.name) is already reserved (and occupied) for \(train.name)")

            // If the turnout state is not what we are expecting, this means it is a turnout that is occupied
            // by the wagons behind the train; we are basically looping back into ourself here so stop reserving.
            // This can happen when there is a small loop and the length of the train is such that the head of
            // the train tries to reserve a block occupied by the tail of the train.
            if turnout.requestedState != state {
                return false
            }
        } else {
            // If the turnout is not occupied, check if we can reserve it. If not,
            // we stop the reservation here because it does not make sense to continue.
            guard turnout.canBeReserved else {
                return false
            }

            // If the turnout can be reserved, remember it and it will actually be reserved
            // when the block that is leads to can also be reserved.
            turnouts.append(TurnoutReservation(turnout: turnout, state: state, sockets: Turnout.Reservation.Sockets(fromSocketId: fromSocketId, toSocketId: toSocketId)))
        }

        return true
    }

    private func rememberTransitions(from previousStep: ResolvedRouteItem?, to step: ResolvedRouteItem, transitions: inout [ITransition]) throws {
        guard let previousStep = previousStep else {
            return
        }
        let fromSocket = previousStep.exitSocket
        let toSocket = step.entrySocket
        let trs = try layout.transitions(from: fromSocket, to: toSocket)
        transitions.append(contentsOf: trs)
    }

    // This method reserves and occupies all the necessary blocks (and parts of the block) to fit
    // the specified train with all its length, taking into account the length of each block.
    func occupyBlocksWith(train: Train) throws {
        let trainVisitor = TrainSpreader(layout: layout)
        let remainingTrainLength = try trainVisitor.spread(train: train) { transition in
            guard transition.reserved == nil else {
                throw LayoutError.transitionAlreadyReserved(transition: transition)
            }
            transition.reserved = train.id
            transition.train = train.id
        } turnoutCallback: { turnoutInfo in
            let turnout = turnoutInfo.turnout

            guard turnout.reserved == nil else {
                throw LayoutError.turnoutAlreadyReserved(turnout: turnout)
            }
            turnout.reserved = .init(train: train.id, sockets: turnoutInfo.sockets)
            turnout.train = train.id
            train.occupied.append(turnout)
        } blockCallback: { block, attributes in
            guard block.reservation == nil || attributes.frontBlock else {
                throw LayoutError.blockAlreadyReserved(block: block)
            }

            let trainInstance = TrainInstance(train.id, attributes.trainDirection)
            block.trainInstance = trainInstance
            block.reservation = .init(trainId: train.id, direction: attributes.trainDirection)
            train.occupied.append(block)
        }
        if remainingTrainLength > 0 {
            throw LayoutError.cannotReserveAllElements(train: train)
        }
    }

    // This methods frees all the reserved elements except the block in which the locomotive is located
    func freeElements(train: Train) throws {
        train.leading.clear()
        train.occupied.clear()

        layout.blocks.elements
            .filter { $0.reservation?.trainId == train.id }
            .forEach { block in
                // Only free a block if the block is not the one the train is located on or
                if block.id != train.block?.id {
                    block.reservation = nil
                    block.trainInstance = nil
                }
            }
        layout.turnouts.elements.filter { $0.reserved?.train == train.id }.forEach { $0.reserved = nil; $0.train = nil }
        layout.transitions.elements.filter { $0.reserved == train.id }.forEach { $0.reserved = nil; $0.train = nil }
    }

    private func debug(_ msg: String) {
        if verbose {
            BTLogger.debug(msg)
        }
    }
}
