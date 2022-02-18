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
        Task {
            try await run(callback: callback)
        }
    }
        
    func cancel() {
        Task {
            try await stopTrain()
            
            feedbackMonitor.stop()
        }
    }
    
    func done() {
        feedbackMonitor.stop()
    }

    private func run(callback: @escaping (CallbackInfo) -> Void) async throws {
        while (true) {
            try await measure(callback: callback)
            if isFinished(for: entryIndex+1) {
                invokeCallback(.done, callback)
                done()
                break
            } else {
                entryIndex += 1
            }
        }
    }
    
    private func measure(callback: @escaping (CallbackInfo) -> Void) async throws {
        await startTrain()
        invokeCallback(.trainStarted, callback)
        
        let feedbacks: [(Identifier<Feedback>, CallbackStep)]
        if forward {
            feedbacks = [(feedbackA, .feedbackA), (feedbackB, .feedbackB), (feedbackC, .feedbackC)]
        } else {
            feedbacks = [(feedbackC, .feedbackC), (feedbackB, .feedbackB), (feedbackA, .feedbackA)]
        }
        
        await waitForFeedback(feedbacks[0].0)
        invokeCallback(feedbacks[0].1, callback)
        
        await waitForFeedback(feedbacks[1].0)
        invokeCallback(feedbacks[1].1, callback)
        
        let t0 = Date()
        
        await waitForFeedback(feedbacks[2].0)
        invokeCallback(feedbacks[2].1, callback)

        let t1 = Date()
        
        await waitForFeedback(feedbacks[2].0, detected: false)

        try await stopTrain()
        invokeCallback(.trainStopped, callback)

        storeMeasurement(t0: t0, t1: t1, distance: forward ? distanceBC : distanceAB)
        
        try await toggleTrainDirection()
        invokeCallback(.trainDirectionToggle, callback)
    }
    
    private func invokeCallback(_ step: CallbackStep, _ callback: @escaping (CallbackInfo) -> Void) {
        let speedEntry = speedEntry(for: entryIndex)
        callback(.init(speedEntry: speedEntry, step: step, progress: progress(for: entryIndex)))
    }
    
    private func startTrain() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                let numberOfSteps = train.speed.speedTable.count
                let speedEntry = speedEntry(for: entryIndex)
                let speedValue = UInt16(Double(speedEntry.steps.value) / Double(numberOfSteps) * 1000)
                
                // TODO: try to refactor to be able to use the layout.setTrainSpeed()
                train.speed.steps = speedEntry.steps
                
                layout.didChange()
                
                interface.execute(command: .speed(address: train.address, decoderType: train.decoder, value: .init(value: speedValue))) {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func stopTrain() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [self] in
                do {
                    try layout.stopTrain(train.id) {
                        // TODO: when we handle the deceleration with a curve, we can invoke completion when the curve reaches 0.
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.250) {
                            continuation.resume(returning: ())
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func toggleTrainDirection() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [self] in
                self.forward.toggle()

                layout.setLocomotiveDirection(train, forward: self.forward) {
                    do {
                        try self.layout.toggleTrainDirectionInBlock(self.train)
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func waitForFeedback(_ feedbackId: Identifier<Feedback>, detected: Bool = true) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                feedbackMonitor.waitForFeedback(feedbackId, detected: detected) {
                    continuation.resume()
                }
            }
        }
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
