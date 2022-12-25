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
    @Published var trains = [SimulatorTrain]()

    @AppStorage("simulatorSpeedFactor") var simulationSpeedFactor = 1.0

    @AppStorage("simulatorTurnoutSpeed") var turnoutSpeed = 0.250
    
    /// The interval of time between the simulation
    let timerInterval = 0.250

    /// Internal global variable used to create a unique port each time a simulator instance
    /// is created, which allows for multiple document to be opened (and operated) at the same time
    private static var globalLocalPort: UInt16 = 15731

    /// The local port used by the simulator
    var localPort: UInt16

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
            registerForLocomotiveChanges()
            registerForTrainChanges()
        }
    }

    private func registerForLocomotiveChanges() {
        guard let layout = layout else {
            return
        }

        let cancellable = layout.$locomotives
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateListOfLocomotives()
            }
        cancellables.append(cancellable)
    }

    private func registerForTrainChanges() {
        guard let layout = layout else {
            return
        }

        let cancellable = layout.$trains
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateListOfTrains()
            }
        cancellables.append(cancellable)
    }

    private func updateListOfLocomotives() {
        guard let layout = layout else {
            return
        }

        locomotives.removeAll(where: { simLoc in
            layout.locomotives[simLoc.id] == nil
        })

        for loc in layout.locomotives.elements {
            if let simLoc = locomotives.first(where: { $0.id == loc.id }) {
                simLoc.speed = loc.speed.actualSteps
                simLoc.directionForward = loc.directionForward
            } else {
                let simLoc = SimulatorLocomotive(loc: loc)
                simLoc.speed = loc.speed.actualSteps
                simLoc.directionForward = loc.directionForward
                locomotives.append(simLoc)
            }
        }

        objectWillChange.send()
    }
    
    private func updateListOfTrains() {
        guard let layout = layout else {
            return
        }

        trains.removeAll(where: { simTrain in
            layout.trains[simTrain.id] == nil
        })

        for train in layout.trains.elements.filter({ $0.block != nil }) {
            updateTrain(train: train)
        }

        objectWillChange.send()
    }

    func trainPositionChangedManually(train: Train) {
        updateTrain(train: train)
    }
    
    func trainAutomaticRouteStarted(train: Train) {
        updateTrain(train: train)
    }
    
    private func updateTrain(train: Train) {
        guard let layout = layout else {
            return
        }

        guard let loc = train.locomotive else {
            return
        }

        guard let block = train.block else {
            return
        }
        
        guard let direction = block.trainInstance?.direction else {
            return
        }

        if let simTrain = trains.first(where: { $0.id == train.id }) {
            simTrain.loc.speed = loc.speed.actualSteps
            simTrain.loc.directionForward = loc.directionForward
            simTrain.loc.block = .init(block: block, direction: direction, directionForward: loc.directionForward)
            BTLogger.simulator.debug("Updated train \(train.name) with direction in block \(direction), moving \((loc.directionForward ? "forward":"backward"))")
        } else {
            guard let simLoc = locomotives.first(where: { $0.id == loc.id }) else {
                return
            }

            let simTrain = SimulatorTrain(id: train.id, name: train.name, loc: simLoc, layout: layout, delegate: self)
            simTrain.loc.speed = loc.speed.actualSteps
            simTrain.loc.directionForward = loc.directionForward
            simTrain.loc.block = .init(block: block, direction: direction, directionForward: loc.directionForward)
            BTLogger.simulator.debug("Updated train \(train.name) with direction in block \(direction), moving \((loc.directionForward ? "forward":"backward"))")
            trains.append(simTrain)
        }
    }
    
    func start(_ port: UInt16 = 8080) {
        try? cs3Server.start(port)

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
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval * BaseTimeFactor, repeats: true) { [weak self] timer in
            self?.timerFired(timer: timer)
        }
    }

    func timerFired(timer: Timer) {
        simulateLayout(duration: timer.timeInterval * simulationSpeedFactor)
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

        case .function(address: let address, decoderType: let decoderType, index: let index, value: let value, priority: _, descriptor: _):
            functionChanged(address: address, decoderType: decoderType, index: index, value: value)

        case .turnout(address: let address, state: let state, power: let power, priority: _, descriptor: _):
            if enabled {
                turnoutChanged(address: address, state: state, power: power)
            }

        case .feedback(deviceID: _, contactID: _, oldValue: _, newValue: _, time: _, priority: _, descriptor: _):
            break

        case .locomotives(priority: _, descriptor: _):
            // Note: this is now provided by the MarklinCS3Server which serves the locomotives over http
            break

        case .queryDirection(address: let address, decoderType: let decoderType, priority: _, descriptor: _):
            provideDirection(address: address.actualAddress(for: decoderType))

        case .unknown(command: _):
            break
        }
    }

    func turnoutChanged(address: CommandTurnoutAddress, state: UInt8, power: UInt8) {
        BTLogger.simulator.debug("Turnout changed for \(address.address.toHex()): state \(state), power \(power)")
        let message = MarklinCANMessageFactory.accessory(addr: address.actualAddress, state: state, power: power)
        DispatchQueue.main.asyncAfter(deadline: .now() + turnoutSpeed) {
            self.send(message.ack)
        }
    }

    func speedChanged(address: UInt32, decoderType: DecoderType?, value: SpeedValue) {
        for train in trains {
            if train.loc.loc.actualAddress == address.actualAddress(for: decoderType) {
                let steps = interface.speedSteps(for: value, decoder: train.loc.loc.decoder)
                train.loc.speed = steps
            }
        }
        let message = MarklinCANMessageFactory.speed(addr: address, speed: value.value)
        send(message.ack)
    }

    func directionChanged(address: UInt32, decoderType: DecoderType?, direction: Command.Direction) {
        BTLogger.simulator.debug("Direction changed for \(address.toHex()): direction \(direction.rawValue)")

        for train in trains {
            if train.loc.loc.actualAddress == address.actualAddress(for: decoderType) {
                train.loc.directionForward = direction == .forward
                toggleTrainDirectionInBlock(locomotive: train.loc)
            }
        }

        // Send back the acknowledgement for this command
        DispatchQueue.global(qos: .background).async {
            let message = MarklinCANMessageFactory.direction(addr: address, direction: direction == .forward ? .forward : .backward)
            self.send(message.ack)
        }
    }

    func functionChanged(address: UInt32, decoderType _: DecoderType?, index: UInt8, value: UInt8) {
        let message = MarklinCANMessageFactory.function(addr: address, index: index, value: value)
        send(message.ack)
    }

    func provideDirection(address: UInt32) {
        guard let train = trains.first(where: { $0.loc.loc.actualAddress == address }) else {
            BTLogger.simulator.error("Unable to find a locomotive for address \(address.toHex())")

            // As per spec 3.5, an answer is always returned, even when a locomotive is not known.
            DispatchQueue.main.async {
                let message = MarklinCANMessageFactory.direction(addr: address, direction: .nochange)
                self.send(message.ack)
            }
            return
        }
        let message = MarklinCANMessageFactory.direction(addr: address, direction: train.loc.directionForward ? .forward : .backward)
        send(message.ack)
    }

    func setFeedback(feedback: Feedback, value: UInt8) {
        let oldValue: UInt8 = feedback.detected ? 1 : 0
        let message = MarklinCANMessageFactory.feedback(deviceID: feedback.deviceID, contactID: feedback.contactID, oldValue: oldValue, newValue: value, time: 0)
        send(message.ack)
    }

    func setLocomotiveDirection(locomotive: SimulatorLocomotive, directionForward: Bool) {
        // Remember this direction in the simulator train itself
        locomotive.directionForward = directionForward
        toggleTrainDirectionInBlock(locomotive: locomotive)

        // Note: directionForward is actually ignored because the message sent by the Central Station is `emergencyStop`
        // and the client must request the locomotive direction explicitly.
        let message = MarklinCANMessageFactory.emergencyStop(addr: locomotive.loc.actualAddress)
        send(message)
    }

    /// Simulates a change in speed from the Central Station 3
    /// - Parameter locomotive: the locomotive that had his speed changed
    func setLocomotiveSpeed(locomotive: SimulatorLocomotive) {
        let value = interface.speedValue(for: locomotive.speed, decoder: locomotive.loc.decoder)
        let message = MarklinCANMessageFactory.speed(addr: locomotive.loc.actualAddress, speed: value.value)
        send(message)
        send(message.ack) // Send also the acknowledgement
    }

    func send(_ message: MarklinCANMessage) {
        server?.connections.forEach { connection in
            connection.send(data: message.data)
        }
    }
    
    func toggleTrainDirectionInBlock(locomotive: SimulatorLocomotive) {
        if let block = locomotive.block, locomotive.directionForward != block.directionForward {
            let newDirection = block.direction.opposite
            locomotive.block = .init(block: block.block, direction: newDirection, directionForward: locomotive.directionForward)
            BTLogger.simulator.debug("Changed locomotive \(locomotive.id) direction to \(newDirection)")
        }
    }

    func simulateLayout(duration: TimeInterval) {
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

            guard let simTrain = trains.first(where: { $0.id == train.id }) else {
                continue
            }

            guard let loc = train.locomotive else {
                continue
            }
            
            guard loc.speed.actualKph > 0 else {
                return
            }

            do {
                try simTrain.update(speed: loc.speed.actualKph, duration: duration)
            } catch {
                BTLogger.simulator.error("\(train.name): \(error.localizedDescription)")
            }
            
        }
    }
            
    func triggerFeedback(feedback: Feedback) {
        setFeedback(feedback: feedback, value: 1)
        Timer.scheduledTimer(withTimeInterval: 0.25 * BaseTimeFactor, repeats: false) { _ in
            self.setFeedback(feedback: feedback, value: 0)
        }
    }
}

extension MarklinCommandSimulator: SimulatorTrainDelegate {
    func trainDidChange(event: SimulatorTrainEvent) {
        switch event {
        case .distanceUpdated:
            break
            
        case .movedToNextBlock(let block):
            // Ensure all the feedbacks of the current block is turned off, otherwise there will be
            // an unexpected feedback error in the layout. This happens when there is less than 250ms
            // between the time the feedback was triggered (because the feedback gets reset after 250ms)
            for bf in block.feedbacks {
                if let feedback = layout?.feedbacks[bf.feedbackId] {
                    setFeedback(feedback: feedback, value: 0)
                }
            }

        case .movedToNextTurnout(_):
            break
            
        case .triggerFeedback(let feedback):
            triggerFeedback(feedback: feedback)
        }
    }
    
}

private extension Locomotive {
    var actualAddress: UInt32 {
        address.actualAddress(for: decoder)
    }
}
