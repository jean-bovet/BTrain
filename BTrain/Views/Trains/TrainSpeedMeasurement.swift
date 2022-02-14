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
        
    @Published var running = false

    private var entryIndex = 0
    
    struct Properties {
        let interface: CommandInterface
        let train: Train
        let selectedSpeedEntries: Set<TrainSpeed.SpeedTableEntry.ID>
        let feedbackA: Identifier<Feedback>
        let feedbackB: Identifier<Feedback>
        let feedbackC: Identifier<Feedback>
    }
    
    func start(properties: Properties, callback: @escaping (String, Double) -> Void) throws {
        guard !running else {
            throw MeasurementError.alreadyRunning
        }

        running = true
        entryIndex = 0
        run(properties: properties, callback: callback)
    }
    
    func run(properties: Properties, callback: @escaping (String, Double) -> Void) {
        let entries = properties.selectedSpeedEntries.sorted()
        let speedEntry = properties.train.speed.speedTable[entryIndex]
        callback("Measuring speed for step \(speedEntry.steps.value)", Double(entryIndex+1) / Double(entries.count))
        measure(properties: properties, speedEntry: speedEntry) {
            self.entryIndex += 1
            if self.entryIndex >= entries.count {
                self.running = false
            } else {
                self.run(properties: properties, callback: callback)
            }
        }
    }
    
    func measure(properties: Properties, speedEntry: TrainSpeed.SpeedTableEntry, completion: @escaping CompletionBlock) {
        startTrain(properties: properties, speedEntry: speedEntry) {
            self.waitForFeedback(properties.feedbackA) {
                self.waitForFeedback(properties.feedbackB) {
                    let t0 = Date()
                    self.waitForFeedback(properties.feedbackC) {
                        let t1 = Date()
                        self.stopTrain(properties: properties) {
                            self.storeMeasurement(t0: t0, t1: t1)
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    func startTrain(properties: Properties, speedEntry: TrainSpeed.SpeedTableEntry, completion: @escaping CompletionBlock) {
        let train = properties.train
        let numberOfSteps = train.speed.speedTable.count
        let speedValue = UInt16(Double(speedEntry.steps.value) / Double(numberOfSteps)) * 1000

        properties.interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: .init(value: speedValue))) {
            completion()
        }
    }
    
    func stopTrain(properties: Properties, completion: @escaping CompletionBlock) {
        let train = properties.train
        properties.interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: .init(value: 0))) {
            completion()
        }
    }
    
    func waitForFeedback(_ feedbackId: Identifier<Feedback>, completion: CompletionBlock) {
        completion()
    }
    
    func storeMeasurement(t0: Date, t1: Date) {
        let duration = t1.timeIntervalSince(t0)
        print("Duration is \(duration)")
    }
    
    func cancel() {
        running = false
    }
}
