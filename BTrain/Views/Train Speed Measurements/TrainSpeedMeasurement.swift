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

// This class performs the automatic measurement of the real speed of a locomotive
// by using 3 feedbacks and running the locomotive between these feedbacks at various decoder steps.
final class TrainSpeedMeasurement {
            
    let layout: Layout
    let interface: CommandInterface
    let train: Train

    let speedEntries: Set<TrainSpeed.SpeedTableEntry.ID>
    let feedbackA: Identifier<Feedback>
    let feedbackB: Identifier<Feedback>
    let feedbackC: Identifier<Feedback>
    let distanceAB: Double
    let distanceBC: Double
    
    let feedbackMonitor: FeedbackMonitor
    
    private var entryIndex = 0
    private var forward = true
        
    enum CallbackStep {
        case trainStarted
        case feedbackA
        case feedbackB
        case feedbackC
        case trainStopped
        case trainDirectionToggle
        case done
    }
    
    struct CallbackInfo {
        let speedEntry: TrainSpeed.SpeedTableEntry
        let step: CallbackStep
        let progress: Double
    }
    
    init(layout: Layout, interface: CommandInterface, train: Train,
         speedEntries: Set<TrainSpeed.SpeedTableEntry.ID>,
         feedbackA: Identifier<Feedback>, feedbackB: Identifier<Feedback>, feedbackC: Identifier<Feedback>,
         distanceAB: Double, distanceBC: Double) {
        self.layout = layout
        self.interface = interface
        self.train = train
        self.speedEntries = speedEntries
        self.feedbackA = feedbackA
        self.feedbackB = feedbackB
        self.feedbackC = feedbackC
        self.distanceAB = distanceAB
        self.distanceBC = distanceBC
        self.feedbackMonitor = FeedbackMonitor(layout: layout, interface: interface)
    }
        
    func start(callback: @escaping (CallbackInfo) -> Void) {
        feedbackMonitor.start()

        forward = train.directionForward
        entryIndex = 0
        run(callback: callback)
    }
        
    func cancel() {
        stopTrain {
            self.feedbackMonitor.stop()
        }
    }
    
    func done() {
        feedbackMonitor.stop()
    }

    private func run(callback: @escaping (CallbackInfo) -> Void) {
        let speedEntry = speedEntry(for: entryIndex)
        measure(speedEntry: speedEntry, callback: callback) {
            if self.isFinished(for: self.entryIndex+1) {
                callback(.init(speedEntry: speedEntry, step: .done, progress: self.progress(for: self.entryIndex)))
                self.done()
            } else {
                self.entryIndex += 1
                self.run(callback: callback)
            }
        }
    }
    
    private func measure(speedEntry: TrainSpeed.SpeedTableEntry, callback: @escaping (CallbackInfo) -> Void, completion: @escaping CompletionBlock) {
        startTrain(speedEntry: speedEntry) {
            callback(.init(speedEntry: speedEntry, step: .trainStarted, progress: self.progress(for: self.entryIndex)))
            if self.forward {
                self.waitForFeedback(self.feedbackA) {
                    callback(.init(speedEntry: speedEntry, step: .feedbackA, progress: self.progress(for: self.entryIndex)))
                    self.waitForFeedback(self.feedbackB) {
                        callback(.init(speedEntry: speedEntry, step: .feedbackB, progress: self.progress(for: self.entryIndex)))
                        let t0 = Date()
                        self.waitForFeedback(self.feedbackC) {
                            callback(.init(speedEntry: speedEntry, step: .feedbackC, progress: self.progress(for: self.entryIndex)))
                            let t1 = Date()
                            self.waitForFeedback(self.feedbackC, detected: false) {
                                self.stopTrain() {
                                    callback(.init(speedEntry: speedEntry, step: .trainStopped, progress: self.progress(for: self.entryIndex)))
                                    self.storeMeasurement(t0: t0, t1: t1, distance: self.distanceBC)
                                    self.toggleTrainDirection() {
                                        callback(.init(speedEntry: speedEntry, step: .trainDirectionToggle, progress: self.progress(for: self.entryIndex)))
                                        completion()
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                self.waitForFeedback(self.feedbackC) {
                    callback(.init(speedEntry: speedEntry, step: .feedbackC, progress: self.progress(for: self.entryIndex)))
                    self.waitForFeedback(self.feedbackB) {
                        callback(.init(speedEntry: speedEntry, step: .feedbackB, progress: self.progress(for: self.entryIndex)))
                        let t0 = Date()
                        self.waitForFeedback(self.feedbackA) {
                            callback(.init(speedEntry: speedEntry, step: .feedbackA, progress: self.progress(for: self.entryIndex)))
                            let t1 = Date()
                            self.waitForFeedback(self.feedbackA, detected: false) {
                                self.stopTrain() {
                                    callback(.init(speedEntry: speedEntry, step: .trainStopped, progress: self.progress(for: self.entryIndex)))
                                    self.storeMeasurement(t0: t0, t1: t1, distance: self.distanceAB)
                                    self.toggleTrainDirection() {
                                        callback(.init(speedEntry: speedEntry, step: .trainDirectionToggle, progress: self.progress(for: self.entryIndex)))
                                        completion()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func startTrain(speedEntry: TrainSpeed.SpeedTableEntry, completion: @escaping CompletionBlock) {
        let numberOfSteps = train.speed.speedTable.count
        let speedValue = UInt16(Double(speedEntry.steps.value) / Double(numberOfSteps) * 1000)

        // TODO: try to refactor to be able to use the layout.setTrainSpeed()
        train.speed.steps = speedEntry.steps
        
        layout.didChange()
        
        interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: .init(value: speedValue))) {
            completion()
        }
    }
    
    private func stopTrain(completion: @escaping CompletionBlock) {
        do {
            try layout.stopTrain(train.id) {
                // TODO: when we handle the deceleration with a curve, we can invoke completion when the curve reaches 0.
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.250) {
                    completion()
                }
            }
        } catch {
            // TODO throw
        }
    }
    
    private func toggleTrainDirection(completion: @escaping CompletionBlock) {
        self.forward.toggle()
        layout.setLocomotiveDirection(train, forward: self.forward) {
            do {
                try self.layout.toggleTrainDirectionInBlock(self.train)
                completion()
            } catch {
                print("Error \(error)")
                // TODO: log? and report to the UX somehow
            }
        }
    }
    
    private func waitForFeedback(_ feedbackId: Identifier<Feedback>, detected: Bool = true, completion: @escaping CompletionBlock) {
        feedbackMonitor.waitForFeedback(feedbackId, detected: detected, completion: completion)
    }
    
    private func storeMeasurement(t0: Date, t1: Date, distance: Double) {
        let duration = t1.timeIntervalSince(t0)
        let durationInHour = duration / (60 * 60)
        
        // H0 is 1:87 (1cm in prototype = 0.0115cm in the layout)
        let modelDistanceKm = distance / 100000
        let realDistanceKm = modelDistanceKm * 87
        let speedInKph = realDistanceKm / durationInHour
        
        print("Duration is \(duration): \(speedInKph)")
                
        let entry = speedEntry(for: entryIndex)
        setSpeedEntry(.init(steps: entry.steps, speed: TrainSpeed.UnitKph(speedInKph)), for: entryIndex)
    }
        
    private func speedEntry(for entryIndex: Int) -> TrainSpeed.SpeedTableEntry {
        let entries = speedEntries.sorted()
        let speedTableIndex = Int(entries[entryIndex])
        let speedEntry = train.speed.speedTable[speedTableIndex]
        return speedEntry
    }
    
    private func setSpeedEntry(_ speedEntry: TrainSpeed.SpeedTableEntry, for entryIndex: Int) {
        let entries = speedEntries.sorted()
        let speedTableIndex = Int(entries[entryIndex])
        train.speed.speedTable[speedTableIndex] = speedEntry
    }
    
    private func progress(for entryIndex: Int) -> Double {
        let progress = Double(entryIndex+1) / Double(speedEntries.count)
        return progress
    }
    
    private func isFinished(for entryIndex: Int) -> Bool {
        return entryIndex >= speedEntries.count
    }
}
