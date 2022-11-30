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

import Combine
import Foundation
import Gzip
import SwiftUI

// This class simulates the Marklin Central Station 3 in order for BTrain
// to work offline. It does so by processing the most common commands and
// driving automatically trains that are on enabled routes.
final class MarklinCommandSimulator: Simulator, ObservableObject {
    weak var layout: Layout?
    let interface: CommandInterface

    @Published var started = false
    @Published var enabled = false

    @Published var locomotives = [SimulatorLocomotive]()

    @AppStorage("simulatorRefreshSpeed") var refreshSpeed = 2.0 {
        didSet {
            scheduleTimer()
        }
    }

    @AppStorage("simulatorTurnoutSpeed") var turnoutSpeed = 0.250

    var refreshTimeInterval: TimeInterval {
        4.0 - refreshSpeed
    }

    /// Internal global variable used to create a unique port each time a simulator instance
    /// is created, which allows for multiple document to be opened (and operated) at the same time
    private static var globalLocalPort: UInt16 = 15731

    /// The local port used by the simulator
    var localPort: UInt16

    private var trainArrayChangesCancellable: AnyCancellable?
    private var cancellables = [AnyCancellable]()

    private var server: Server?

    private var cs3Server = MarklinCS3Server.shared

    private var timer: Timer?

    private var connection: ServerConnection? {
        server?.connections.first
    }

    init(layout: Layout, interface: CommandInterface) {
        self.layout = layout
        self.interface = interface

        MarklinCommandSimulator.globalLocalPort += 1
        localPort = MarklinCommandSimulator.globalLocalPort

        // Initialization from the document can sometimes happen in the background,
        // let's make sure these are initialized in the main thread.
        MainThreadQueue.sync {
            registerForTrainChanges()
            registerForTrainBlockChange()
        }
    }

    private func registerForTrainChanges() {
        guard let layout = layout else {
            return
        }

        let cancellable = layout.$trains
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                // When the array of trains changes, we need
                // to re-register for changes for each individual trains
                // because these instances have likely changed.
                self?.registerForTrainBlockChange()

                // Then update the list of trains
                self?.updateListOfTrains()
            }
        trainArrayChangesCancellable = cancellable
    }

    // Register to detect when a train is assigned to a different block,
    // which happens when a train moves from one block to another or when
    // a train is assigned a block for the first time (put into the layout).
    private func registerForTrainBlockChange() {
        guard let layout = layout else {
            return
        }

        cancellables.removeAll()
        for train in layout.trains.elements {
            let cancellable = train.$blockId
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.updateListOfTrains()
                }
            cancellables.append(cancellable)
        }
    }

    func updateListOfTrains() {
        guard let layout = layout else {
            return
        }

        // Remove locomotives that are not present anymore
        locomotives.removeAll(where: { simLoc in
            layout.locomotives[simLoc.id] == nil
        })

        // Update existing locomotives, add new ones
        for train in layout.trains.elements.filter({ $0.blockId != nil }) {
            guard let loc = train.locomotive else {
                continue
            }
            if let simTrain = locomotives.first(where: { $0.id == loc.id }) {
                simTrain.speed = loc.speed.actualSteps
                simTrain.directionForward = loc.directionForward
            } else {
                locomotives.append(SimulatorLocomotive(loc: loc))
            }
        }

        objectWillChange.send()
    }

    func start() {
        try? cs3Server.start()

        server = Server(port: localPort)
        server!.didAcceptConnection = { [weak self] connection in
            self?.register(with: connection)
        }
        try! server!.start()
        started = true
    }

    func stop(_ completion: @escaping CompletionBlock) {
        cs3Server.stop()

        let onCompletionBlock = { [weak self] in
            self?.started = false
            self?.enabled = false
            completion()
        }

        if let server = server {
            server.stop {
                onCompletionBlock()
            }
        } else {
            onCompletionBlock()
        }
    }

    func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshTimeInterval * BaseTimeFactor, repeats: true) { [weak self] _ in
            self?.simulateLayout()
        }
    }

    func register(with connection: ServerConnection) {
        connection.receiveMessageCallback = { [weak self] message in
            if let self = self {
                self.handleMessage(message: message)
            }
        }
    }

    private func handleMessage(message: Command) {
        switch message {
        case .go:
            enabled = true
            scheduleTimer()
            send(MarklinCANMessageFactory.go().ack)

        case .stop:
            enabled = false
            timer?.invalidate()
            send(MarklinCANMessageFactory.stop().ack)

        case .emergencyStop(address: let address, decoderType: _, priority: _, descriptor: _):
            send(MarklinCANMessageFactory.emergencyStop(addr: address).ack)

        case .speed(address: let address, decoderType: let decoderType, value: let value, priority: _, descriptor: _):
            if enabled {
                speedChanged(address: address, decoderType: decoderType, value: value)
            }

        case .direction(address: let address, decoderType: let decoderType, direction: let direction, priority: _, descriptor: _):
            if enabled {
                directionChanged(address: address, decoderType: decoderType, direction: direction)
            }

        case .turnout(address: let address, state: let state, power: let power, priority: _, descriptor: _):
            if enabled {
                turnoutChanged(address: address, state: state, power: power)
            }

        case .feedback(deviceID: _, contactID: _, oldValue: _, newValue: _, time: _, priority: _, descriptor: _):
            break

        case .locomotives(priority: _, descriptor: _):
            provideLocomotives()

        case .queryDirection(address: let address, decoderType: let decoderType, priority: _, descriptor: _):
            provideDirection(address: address.actualAddress(for: decoderType))

        case .unknown(command: _):
            break
        }
    }

    func turnoutChanged(address: CommandTurnoutAddress, state: UInt8, power: UInt8) {
        BTLogger.debug("[Simulator] Turnout changed for \(address.address.toHex()): state \(state), power \(power)")
        let message = MarklinCANMessageFactory.accessory(addr: address.actualAddress, state: state, power: power)
        DispatchQueue.main.asyncAfter(deadline: .now() + turnoutSpeed) {
            self.send(message.ack)
        }
    }

    func speedChanged(address: UInt32, decoderType: DecoderType?, value: SpeedValue) {
        for loc in locomotives {
            if loc.loc.actualAddress == address.actualAddress(for: decoderType) {
                let steps = interface.speedSteps(for: value, decoder: loc.loc.decoder)
                loc.speed = steps
            }
        }
        let message = MarklinCANMessageFactory.speed(addr: address, speed: value.value)
        send(message.ack)
    }

    func directionChanged(address: UInt32, decoderType: DecoderType?, direction: Command.Direction) {
        for loc in locomotives {
            if loc.loc.actualAddress == address.actualAddress(for: decoderType) {
                loc.directionForward = direction == .forward
            }
        }

        // Send back the acknowledgement for this command
        DispatchQueue.global(qos: .background).async {
            let message = MarklinCANMessageFactory.direction(addr: address, direction: direction == .forward ? .forward : .backward)
            self.send(message.ack)
        }
    }

    func provideLocomotives() {
        guard let file = Bundle.main.url(forResource: "Locomotives", withExtension: "cs2") else {
            BTLogger.error("[Simulator]  Unable to find the Locomotives.cs2 file")
            return
        }
        let data = try! Data(contentsOf: file)
        var compressedData = try! data.gzipped()

        // Insert the 4 bytes CRC (?)
        compressedData.insert(contentsOf: [0, 0, 0, 0], at: 0)

        // Send the compressed data in the background
        DispatchQueue.global(qos: .background).async {
            let message = MarklinCANMessageFactory.configData(length: UInt32(compressedData.count))
            self.send(message)

            let dataLength = 8 // 8 bytes at a time can be sent out
            let numberOfMessages = Int(round(Double(compressedData.count) / Double(dataLength)))
            for index in 0 ..< numberOfMessages {
                let start = index * dataLength
                let end = min(compressedData.count, (index + 1) * dataLength)
                let slice = compressedData[start ..< end]
                let message = MarklinCANMessageFactory.configData(bytes: [UInt8](slice))
                self.send(message)
            }
        }
    }

    func provideDirection(address: UInt32) {
        guard let loc = locomotives.first(where: { $0.loc.actualAddress == address }) else {
            BTLogger.error("[Simulator] Unable to find a locomotive for address \(address.toHex())")

            // As per spec 3.5, an answer is always returned, even when a locomotive is not known.
            DispatchQueue.main.async {
                let message = MarklinCANMessageFactory.direction(addr: address, direction: .nochange)
                self.send(message.ack)
            }
            return
        }
        let message = MarklinCANMessageFactory.direction(addr: address, direction: loc.directionForward ? .forward : .backward)
        send(message.ack)
    }

    func setFeedback(feedback: Feedback, value: UInt8) {
        let oldValue: UInt8 = feedback.detected ? 1 : 0
        let message = MarklinCANMessageFactory.feedback(deviceID: feedback.deviceID, contactID: feedback.contactID, oldValue: oldValue, newValue: value, time: 0)
        send(message.ack)
    }

    func setTrainDirection(train: SimulatorLocomotive, directionForward: Bool) {
        // Remember this direction in the simulator train itself
        train.directionForward = directionForward

        // Note: directionForward is actually ignored because the message sent by the Central Station is `emergencyStop`
        // and the client must request the locomotive direction explicitly.
        let message = MarklinCANMessageFactory.emergencyStop(addr: train.loc.actualAddress)
        send(message)
    }

    /// Simulates a change in speed from the Central Station 3
    /// - Parameter train: the train that had his speed changed
    func setTrainSpeed(train: SimulatorLocomotive) {
        let value = interface.speedValue(for: train.speed, decoder: train.loc.decoder)
        let message = MarklinCANMessageFactory.speed(addr: train.loc.actualAddress, speed: value.value)
        send(message)
        send(message.ack) // Send also the acknowledgement
    }

    func send(_ message: MarklinCANMessage) {
        server?.connections.forEach { connection in
            connection.send(data: message.data)
        }
    }

    func simulateLayout() {
        guard enabled else {
            return
        }

        guard let layout = layout else {
            return
        }

        for train in layout.trains.elements {
            guard train.scheduling != .unmanaged else {
                continue
            }

            guard let loc = train.locomotive else {
                continue
            }

            guard let simLoc = locomotives.first(where: { $0.loc.id == loc.id }), simLoc.simulate else {
                continue
            }

            guard let route = layout.route(for: train.routeId, trainId: train.id) else {
                continue
            }

            do {
                try simulate(route: route, train: train, loc: loc)
            } catch {
                BTLogger.error(error.localizedDescription)
            }
        }
    }

    func simulate(route: Route, train: Train, loc: Locomotive) throws {
        guard let layout = layout else {
            return
        }

        guard loc.speed.actualKph > 0 else {
            return
        }

        guard let block = layout.blocks[train.blockId] else {
            return
        }

        BTLogger.debug("[Simulator] Simulating route \(route.name) for \(train.name), requested speed \(loc.speed.requestedKph) kph, actual speed \(loc.speed.actualKph) kph")

        if let entryFeedback = try layout.entryFeedback(for: train) {
            // Ensure all the feedbacks of the current block is turned off, otherwise there will be
            // an unexpected feedback error in the layout. This happens when there is less than 250ms
            // between the time the feedback was triggered (because the feedback gets reset after 250ms)
            for bf in block.feedbacks {
                if let feedback = layout.feedbacks[bf.feedbackId] {
                    setFeedback(feedback: feedback, value: 0)
                }
            }

            BTLogger.debug("[Simulator] Trigger feedback \(entryFeedback.feedback.name) to move train \(train.name) to next block \(entryFeedback.block.name)")
            triggerFeedback(feedback: entryFeedback.feedback)
        } else if try layout.atEndOfBlock(train: train) == false {
            // TODO: unit tests
            let naturalDirection = block.trainInstance?.direction == .next
            let feedback: Block.BlockFeedback
            if naturalDirection {
                if train.directionForward {
                    let position = train.position.front?.index ?? block.feedbacks.count
                    feedback = block.feedbacks[position]
                } else {
                    let position = train.position.back?.index ?? block.feedbacks.count
                    feedback = block.feedbacks[position]
                }
            } else {
                if train.directionForward {
                    // Block: [ 3 2 1 ]
                    // Train:  b   f
                    let position = train.position.front?.index ?? 1
                    feedback = block.feedbacks[position - 1]
                } else {
                    // Block: [ 3 2 1 ]
                    // Train:  f   b
                    let position = train.position.back?.index ?? 1
                    feedback = block.feedbacks[position - 1]
                }
            }
            if let feedback = layout.feedbacks[feedback.feedbackId] {
                BTLogger.debug("[Simulator] Trigger feedback \(feedback.name) to move train \(train.name) within \(block.name)")
                triggerFeedback(feedback: feedback)
            }
        } else {
            BTLogger.debug("[Simulator] Nothing to process for route \(route)")
        }
    }

    func triggerFeedback(feedback: Feedback) {
        setFeedback(feedback: feedback, value: 1)
        Timer.scheduledTimer(withTimeInterval: 0.25 * BaseTimeFactor, repeats: false) { _ in
            self.setFeedback(feedback: feedback, value: 0)
        }
    }
}

private extension Locomotive {
    var actualAddress: UInt32 {
        address.actualAddress(for: decoder)
    }
}
