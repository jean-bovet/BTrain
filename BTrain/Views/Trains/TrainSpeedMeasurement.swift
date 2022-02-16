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

final class TrainSpeedMeasurement: ObservableObject {
    
    enum MeasurementError: Error, LocalizedError {
        case alreadyRunning
        
        var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                return "Measurement is already running"
            }
        }
    }
        
    let layout: Layout
    let interface: CommandInterface

    @Published var running = false

    private var entryIndex = 0
    private var forward = true
    
    struct Properties {
        let train: Train
        let selectedSpeedEntries: Set<TrainSpeed.SpeedTableEntry.ID>
        let feedbackA: Identifier<Feedback>
        let feedbackB: Identifier<Feedback>
        let feedbackC: Identifier<Feedback>
        let distanceAB: Double
        let distanceBC: Double
    }
    
    init(layout: Layout, interface: CommandInterface){
        self.layout = layout
        self.interface = interface
    }
    
    func start(properties: Properties, callback: @escaping (String, Double) -> Void) throws {
        guard !running else {
            throw MeasurementError.alreadyRunning
        }
        
        registerForFeedbackChanges()

        running = true
        forward = properties.train.directionForward
        entryIndex = 0
        run(properties: properties, callback: callback)
    }
    
    private func run(properties: Properties, callback: @escaping (String, Double) -> Void) {
        let entries = properties.selectedSpeedEntries.sorted()
        let speedTableIndex = Int(entries[entryIndex])
        let speedEntry = properties.train.speed.speedTable[speedTableIndex]
        callback("Measuring speed for step \(speedEntry.steps.value)", Double(entryIndex+1) / Double(entries.count))
        measure(properties: properties, speedEntry: speedEntry) {
            self.entryIndex += 1
            if self.entryIndex >= entries.count {
                self.done()
            } else {
                self.run(properties: properties, callback: callback)
            }
        }
    }
    
    private func measure(properties: Properties, speedEntry: TrainSpeed.SpeedTableEntry, completion: @escaping CompletionBlock) {
        startTrain(properties: properties, speedEntry: speedEntry) {
            if self.forward {
                self.waitForFeedback(properties.feedbackA) {
                    self.waitForFeedback(properties.feedbackB) {
                        let t0 = Date()
                        self.waitForFeedback(properties.feedbackC) {
                            let t1 = Date()
                            self.stopTrain(properties: properties) {
                                self.storeMeasurement(properties: properties, t0: t0, t1: t1, distance: properties.distanceBC)
                                self.toggleTrainDirection(properties: properties) {
                                    completion()
                                }
                            }
                        }
                    }
                }
            } else {
                self.waitForFeedback(properties.feedbackC) {
                    self.waitForFeedback(properties.feedbackB) {
                        let t0 = Date()
                        self.waitForFeedback(properties.feedbackA) {
                            let t1 = Date()
                            self.stopTrain(properties: properties) {
                                self.storeMeasurement(properties: properties, t0: t0, t1: t1, distance: properties.distanceAB)
                                self.toggleTrainDirection(properties: properties) {
                                    completion()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startTrain(properties: Properties, speedEntry: TrainSpeed.SpeedTableEntry, completion: @escaping CompletionBlock) {
        let train = properties.train
        let numberOfSteps = train.speed.speedTable.count
        let speedValue = UInt16(Double(speedEntry.steps.value) / Double(numberOfSteps) * 1000)

        // TODO: try to refactor to be able to use the layout.setTrainSpeed()
        train.speed.steps = speedEntry.steps
        
        layout.didChange()
        
        interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: .init(value: speedValue))) {
            completion()
        }
    }
    
    private func stopTrain(properties: Properties, completion: @escaping CompletionBlock) {
        let train = properties.train
        do {
            try layout.stopTrain(train.id)
        } catch {
            // TODO throw
        }
        completion()
    }
    
    private func toggleTrainDirection(properties: Properties, completion: @escaping CompletionBlock) {
        let train = properties.train
        do {
            self.forward.toggle()
            layout.setLocomotiveDirection(train, forward: self.forward)
            try layout.toggleTrainDirectionInBlock(train)
        } catch {
            // TODO throw
        }
        completion()
    }
    
    private func waitForFeedback(_ feedbackId: Identifier<Feedback>, completion: @escaping CompletionBlock) {
        expectedFeedbackId = feedbackId
        expectedFeedbackCallback = { [weak self] in
            self?.expectedFeedbackId = nil
            self?.expectedFeedbackCallback = nil
            completion()
        }
    }
    
    private func storeMeasurement(properties: Properties, t0: Date, t1: Date, distance: Double) {
        let duration = t1.timeIntervalSince(t0)
        let durationInHour = duration / (60 * 60)
        
        // H0 is 1:87 (1cm in prototype = 0.0115cm in the layout)
        let modelDistanceKm = distance / 100000
        let realDistanceKm = modelDistanceKm * 87
        let speedInKph = realDistanceKm / durationInHour
        
        print("Duration is \(duration): \(speedInKph)")
        
        let entry = properties.train.speed.speedTable[entryIndex]
        properties.train.speed.speedTable[entryIndex] = .init(steps: entry.steps, speed: TrainSpeed.UnitKph(speedInKph))
    }
    
    private var expectedFeedbackId: Identifier<Feedback>?
    private var expectedFeedbackCallback: CompletionBlock?
    
    private var feedbackChangeUUID: UUID?
    
    private func registerForFeedbackChanges() {
        feedbackChangeUUID = interface.register(forFeedbackChange: { [weak self] deviceID, contactID, value in
            guard let sSelf = self else {
                return
            }
            DispatchQueue.main.async {
                guard let feedback = sSelf.layout.feedbacks.find(deviceID: deviceID, contactID: contactID) else {
                    return
                }
                
                guard value == 1 else {
                    return
                }
                
                if feedback.id == sSelf.expectedFeedbackId {
                    sSelf.expectedFeedbackCallback?()
                }
            }
        })
    }
    
    private func unregisterForFeedbackChanges() {
        if let feedbackChangeUUID = feedbackChangeUUID {
            interface.unregister(uuid: feedbackChangeUUID)
        }
    }
    
    func cancel() {
        unregisterForFeedbackChanges()
        running = false
    }
    
    func done() {
        unregisterForFeedbackChanges()
        running = false
    }
}
