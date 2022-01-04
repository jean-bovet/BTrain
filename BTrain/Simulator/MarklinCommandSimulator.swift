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
import Gzip
import Combine

final class SimulatorTrain: ObservableObject, Element {
    let id: Identifier<Train>
    let train: ITrain
    
    @Published var directionForward = true
    @Published var speed = 0.0
        
    init(train: ITrain) {
        self.id = train.id
        self.train = train
        self.directionForward = train.directionForward
        self.speed = Double(train.speed)
    }
}
    
final class MarklinCommandSimulator: ObservableObject {
    
    let layout: Layout
    
    @Published var started = false
    @Published var enabled = false
    
    @Published var trains = [SimulatorTrain]()

    private var cancellables = [AnyCancellable]()

    private var server: Server?

    private var timer: Timer?
    
    private var connection: ServerConnection? {
        return server?.connections.first
    }
    
    init(layout: Layout) {
        self.layout = layout
        
        registerForTrainChanges()
        registerForTrainBlockChange()
    }

    func registerForTrainChanges() {
        let cancellable = layout.$mutableTrains
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { value in
                self.updateListOfTrains()
            }
        cancellables.append(cancellable)
    }

    func registerForTrainBlockChange() {
        for train in layout.mutableTrains {
            let cancellable = train.$blockId
                .removeDuplicates()
                .receive(on: RunLoop.main)
                .sink { value in
                    self.updateListOfTrains()
                }
            cancellables.append(cancellable)
        }
    }

    func updateListOfTrains() {
        self.trains = layout.trains.filter({ $0.blockId != nil }).map({ train in
            return SimulatorTrain(train: train)
        })
    }
    
    func start() {
        server = Server(port: 15731)
        server?.didAcceptConnection = { connection in
            self.register(with: connection)
        }
        try! server?.start()
        started = true
    }
        
    func stop() {
        server?.stop()
        started = false
    }
    
    func register(with connection: ServerConnection) {
        connection.receiveMessageCallback = { message in
            switch(message) {
            case .go:
                self.enabled = true
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                    self.runLayout()
                }

            case .stop:
                self.enabled = false
                self.timer?.invalidate()

            case .emergencyStop(address: _, descriptor: _):
                break
                
            case .speed(address: _, speed: _, descriptor: _):
                break
            case .direction(address: _, direction: _, descriptor: _):
                break
            case .turnout(address: _, state: _, power: _, descriptor: _):
                break
            case .feedback(deviceID: _, contactID: _, oldValue: _, newValue: _, time: _, descriptor: _):
                break
                
            case .locomotives(descriptor: _):
                self.provideLocomotives()
                break

            case .queryDirection(address: let address, descriptor: _):
                self.provideDirection(address: address.address)
                break

            case .unknown(command: _):
                break
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
        guard let train = trains.first(where: { $0.train.address.actualAddress == address }) else {
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
        let message = MarklinCANMessageFactory.emergencyStop(addr: train.train.address.actualAddress)
        send(message)
    }
    
    func setTrainSpeed(train: SimulatorTrain, value: Double) {
        let message = MarklinCANMessageFactory.speed(addr: train.train.address.actualAddress, speed: UInt16(value))
        send(message)
    }
    
    func send(_ message: MarklinCANMessage) {
        server?.connections.forEach({ connection in
            connection.send(data: message.data)
        })
    }
    
    func runLayout() {
        for train in layout.trains {
            guard let routeId = train.routeId else {
                continue
            }
            
            guard let route = layout.route(for: routeId, trainId: train.id) else {
                continue
            }
            
            do {
                try tick(route: route, train: train)
            } catch {
                BTLogger.error(error.localizedDescription)
            }
        }
    }
    
    func tick(route: Route, train: ITrain) throws {
        guard train.speed > 0 else {
            return
        }
        
        guard route.enabled else {
            return
        }
        
        guard let block = layout.currentBlock(train: train) else {
            return
        }
                        
        if !layout.atEndOfBlock(train: train)  {
            let naturalDirection = block.trainNaturalDirection
            let feedback = block.feedbacks[naturalDirection ? train.position : train.position - 1]
            if let feedback = layout.feedback(for: feedback.feedbackId) {
                triggerFeedback(feedback: feedback, value: 1)
            }
        } else if let nextBlock = layout.nextBlock(train: train), layout.atEndOfBlock(train: train) {
            let (feedback, _) = try layout.feedbackTriggeringTransition(from: block, to: nextBlock)
            if let feedback = feedback {
                triggerFeedback(feedback: feedback, value: 1)
            }
        } else {
            print("[Simulator] Nothing to process for route \(route)")
        }
    }

    func triggerFeedback(feedback: Feedback, value: UInt8) {
        setFeedback(feedback: feedback, value: 1)
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { timer in
            self.setFeedback(feedback: feedback, value: 0)
        }
    }
}
