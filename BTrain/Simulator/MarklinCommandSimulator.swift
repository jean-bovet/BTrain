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
import Gzip
import Combine
import SwiftUI

// This class simulates the Marklin Central Station 3 in order for BTrain
// to work offline. It does so by processing the most common commands and
// driving automatically trains that are on enabled routes.
final class MarklinCommandSimulator: Simulator, ObservableObject {
    
    weak var layout: Layout?
    let interface: CommandInterface
    
    @Published var started = false
    @Published var enabled = false
    
    @Published var trains = [SimulatorTrain]()

    @AppStorage("simulatorRefreshSpeed") var refreshSpeed = 2.0 {
        didSet {
            scheduleTimer()
        }
    }
    
    var refreshTimeInterval: TimeInterval {
        return 4.0 - refreshSpeed
    }
    
    private var trainArrayChangesCancellable: AnyCancellable?
    private var cancellables = [AnyCancellable]()

    private var server: Server?

    private var timer: Timer?
    
    private var connection: ServerConnection? {
        return server?.connections.first
    }
    
    init(layout: Layout, interface: CommandInterface) {
        self.layout = layout
        self.interface = interface
        
        // Initialization from the document can sometimes happen in the background,
        // let's make sure these are initialized in the main thread.
        MainThreadQueue.sync {
            registerForTrainChanges()
            registerForTrainBlockChange()
        }
    }

    func registerForTrainChanges() {
        guard let layout = layout else {
            return
        }

        let cancellable = layout.$trains
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
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
    func registerForTrainBlockChange() {
        guard let layout = layout else {
            return
        }

        cancellables.removeAll()
        for train in layout.trains {
            let cancellable = train.$blockId
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { [weak self] value in
                    self?.updateListOfTrains()
                }
            cancellables.append(cancellable)
        }
    }

    func updateListOfTrains() {
        guard let layout = layout else {
            return
        }

        // Remove train that are not present anymore
        trains.removeAll(where: { simTrain in
            return layout.train(for: simTrain.train.id) == nil
        })
        
        // Update existing trains, add new ones
        for train in layout.trains.filter({$0.blockId != nil}) {
            if let simTrain = trains.first(where: { $0.train.id == train.id }) {
                simTrain.speed = train.speed.actualSteps
                simTrain.directionForward = train.directionForward
            } else {
                trains.append(SimulatorTrain(train: train))
            }
        }
        
        objectWillChange.send()
    }
    
    func start() {
        server = Server(port: 15731)
        server!.didAcceptConnection = { [weak self] connection in
            self?.register(with: connection)
        }
        try! server!.start()
        started = true
    }
        
    func stop(_ completion: @escaping CompletionBlock) {
        let onCompletionBlock = { [weak self] in
            self?.started = false
            self?.enabled = false
            completion()
        }
        
        if let server = server {
            server.stop() {
                onCompletionBlock()
            }
        } else {
            onCompletionBlock()
        }
    }
    
    func scheduleTimer() {
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: refreshTimeInterval, repeats: true) { [weak self] timer in
            self?.simulateLayout()
        }
    }
    
    func register(with connection: ServerConnection) {
        connection.receiveMessageCallback = { [weak self] message in
            switch(message) {
            case .go:
                self?.enabled = true
                self?.scheduleTimer()

            case .stop:
                self?.enabled = false
                self?.timer?.invalidate()

            case .emergencyStop(address: _, decoderType: _, priority: _, descriptor: _):
                break
                
            case .speed(address: let address, decoderType: let decoderType, value: let value, priority: _, descriptor: _):
                self?.speedChanged(address: address, decoderType: decoderType, value: value)
                break
                
            case .direction(address: let address, decoderType: let decoderType, direction: let direction, priority: _, descriptor: _):
                self?.directionChanged(address: address, decoderType: decoderType, direction: direction)
                break
                
            case .turnout(address: _, state: _, power: _, priority: _, descriptor: _):
                break
                
            case .feedback(deviceID: _, contactID: _, oldValue: _, newValue: _, time: _, priority: _, descriptor: _):
                break
                
            case .locomotives(priority: _, descriptor: _):
                self?.provideLocomotives()
                break

            case .queryDirection(address: let address, decoderType: let decoderType, priority: _, descriptor: _):
                self?.provideDirection(address: address.actualAddress(for: decoderType))
                break

            case .unknown(command: _):
                break
            }
        }
    }
    
    func speedChanged(address: UInt32, decoderType: DecoderType?, value: SpeedValue) {
        for train in trains {
            if train.train.actualAddress == address.actualAddress(for: decoderType) {
                let steps = interface.speedSteps(for: value, decoder: train.train.decoder)
                train.speed = steps
            }
        }
    }

    func directionChanged(address: UInt32, decoderType: DecoderType?, direction: Command.Direction) {
        for train in trains {
            if train.train.actualAddress == address.actualAddress(for: decoderType) {
                train.directionForward = direction == .forward
            }
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
        compressedData.insert(contentsOf: [0,0,0,0], at: 0)
        
        // Send the compressed data in the background
        DispatchQueue.global(qos: .background).async {
            let message = MarklinCANMessageFactory.configData(length: UInt32(compressedData.count))
            self.send(message)

            let dataLength = 8 // 8 bytes at a time can be sent out
            let numberOfMessages = Int(round(Double(compressedData.count) / Double(dataLength)))
            for index in 0..<numberOfMessages {
                let start = index * dataLength
                let end = min(compressedData.count, (index + 1) * dataLength)
                let slice = compressedData[start..<end]
                let message = MarklinCANMessageFactory.configData(bytes: [UInt8](slice))
                self.send(message)
            }
        }
    }
    
    func provideDirection(address: UInt32) {
        guard let train = trains.first(where: { $0.train.actualAddress == address }) else {
            BTLogger.error("[Simulator] Unable to find a locomotive for address \(address.toHex())")
            return
        }
        
        let message = MarklinCANMessageFactory.direction(addr: address, direction: train.directionForward ? 1 : 2)
        send(message)
    }
    
    func setFeedback(feedback: Feedback, value: UInt8) {
        let oldValue: UInt8 = feedback.detected ? 1 : 0
        let message = MarklinCANMessageFactory.feedback(deviceID: feedback.deviceID, contactID: feedback.contactID, oldValue: oldValue, newValue: value, time: 0)
        send(message)
    }

    func setTrainDirection(train: SimulatorTrain, directionForward: Bool) {
        // Remember this direction in the simulator train itself
        train.directionForward = directionForward
        
        // Note: directionForward is actually ignored because the message sent by the Digital Control System is `emergencyStop`
        // and apparently the client must request the locomotive direction explicitely.
        let message = MarklinCANMessageFactory.emergencyStop(addr: train.train.actualAddress)
        send(message)
    }
    
    func setTrainSpeed(train: SimulatorTrain) {
        let value = interface.speedValue(for: train.speed, decoder: train.train.decoder)
        let message = MarklinCANMessageFactory.speed(addr: train.train.actualAddress, speed: value.value)
        send(message)
    }
    
    func send(_ message: MarklinCANMessage) {
        server?.connections.forEach({ connection in
            connection.send(data: message.data)
        })
    }
    
    func simulateLayout() {
        guard enabled else {
            return
        }
        
        guard let layout = layout else {
            return
        }

        for train in layout.trains {
            guard train.automaticScheduling else {
                continue
            }
            
            guard let simulatorTrain = trains.first(where: {$0.train.id == train.id}), simulatorTrain.simulate else {
                continue
            }
            
            guard let routeId = train.routeId else {
                continue
            }
            
            guard let route = layout.route(for: routeId, trainId: train.id) else {
                continue
            }
            
            do {
                try simulate(route: route, train: train)
            } catch {
                BTLogger.error(error.localizedDescription)
            }
        }
    }
    
    func simulate(route: Route, train: Train) throws {
        guard train.speed.requestedKph > 0 else {
            return
        }
                
        guard let layout = layout else {
            return
        }

        guard let block = layout.currentBlock(train: train) else {
            return
        }
                       
        BTLogger.debug("[Simulator] Simulating route \(route.name) for \(train.name)")

        if try !layout.atEndOfBlock(train: train)  {
            let naturalDirection = block.train?.direction == .next
            let feedback = block.feedbacks[naturalDirection ? train.position : train.position - 1]
            if let feedback = layout.feedback(for: feedback.feedbackId) {
                BTLogger.debug("[Simulator] Trigger feedback \(feedback.name) to move train \(train.name) within \(block.name)")
                triggerFeedback(feedback: feedback)
            }
        } else if let nextBlock = layout.nextBlock(train: train), try layout.atEndOfBlock(train: train) {
            let (feedback, _) = try layout.entryFeedback(from: block, to: nextBlock)
            if let feedback = feedback {
                // Ensure all the feedbacks of the current block is turned off, otherwise there will be
                // an unexpected feedback error in the layout. This happens when there is less than 250ms
                // between the time the feedback was triggered (because the feedback gets reset after 250ms)
                for bf in block.feedbacks {
                    if let feedback = layout.feedback(for: bf.feedbackId) {
                        setFeedback(feedback: feedback, value: 0)
                    }
                }
                
                BTLogger.debug("[Simulator] Trigger feedback \(feedback.name) to move train \(train.name) to next block \(nextBlock.name)")
                triggerFeedback(feedback: feedback)
            }
        } else {
            BTLogger.debug("[Simulator] Nothing to process for route \(route)")
        }
    }

    func triggerFeedback(feedback: Feedback) {
        setFeedback(feedback: feedback, value: 1)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { timer in
            self.setFeedback(feedback: feedback, value: 0)
        }
    }
}

private extension Train {
    
    var actualAddress: UInt32 {
        return address.actualAddress(for: decoder)
    }

}
