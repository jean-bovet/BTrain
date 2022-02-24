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
    
    // True if the measurement is done in the simulator,
    // which is going to affect some delays after stopping the train
    let simulator: Bool
    
    private var entryIndex = 0
    private var forward = true
    private var task: Task<Void, Error>?
    
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
         distanceAB: Double, distanceBC: Double, simulator: Bool = false) {
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
        self.simulator = simulator
    }
        
    func start(callback: @escaping (CallbackInfo) -> Void) {
        if let task = task {
            log("Cancel already existing task")
            task.cancel()
        }

        log("Preparing to measure \(train) with direction \(train.directionForward ? "forward" : "backward" )")

        feedbackMonitor.start()

        forward = train.directionForward
        entryIndex = 0
        task = Task {
            try await run(callback: callback)
        }
    }
        
    func cancel() {
        task?.cancel()
        Task {
            try await stopTrain()
            
            feedbackMonitor.stop()
        }
    }
    
    func done() {
        feedbackMonitor.stop()
    }

    private func log(_ msg: String) {
        BTLogger.debug("􀍾 \(msg)")
    }
    
    private func run(callback: @escaping (CallbackInfo) -> Void) async throws {
        log("Start measuring")
        while (true) {
            try Task.checkCancellation()
            try await measure(callback: callback)
            if isFinished(for: entryIndex+1) {
                invokeCallback(.done, callback)
                done()
                log("Done measuring")
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
                
        try Task.checkCancellation()

        await waitForFeedback(feedbacks[1].0)
        let t0 = Date()
        invokeCallback(feedbacks[1].1, callback)
                
        try Task.checkCancellation()

        await waitForFeedback(feedbacks[2].0)
        let t1 = Date()
        invokeCallback(feedbacks[2].1, callback)
        
        try Task.checkCancellation()

        await waitForFeedback(feedbacks[2].0, detected: false)

        try Task.checkCancellation()

        try await stopTrain()
        invokeCallback(.trainStopped, callback)

        DispatchQueue.main.sync {
            storeMeasurement(t0: t0, t1: t1, distance: forward ? distanceBC : distanceAB)
        }
        
        if !simulator && !Task.isCancelled {
            // Wait a bit before toggling the train direction because a locomotive might still
            // not be fully stopped. Although stopTrain() waits until the train has stopped (from a command
            // control point of view), some locomotive still need some time to stop fully.
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        try Task.checkCancellation()

        try await toggleTrainDirection()
        invokeCallback(.trainDirectionToggle, callback)
    }
    
    private func invokeCallback(_ step: CallbackStep, _ callback: @escaping (CallbackInfo) -> Void) {
        log("Completed step \(step)")
        let speedEntry = speedEntry(for: entryIndex)
        callback(.init(speedEntry: speedEntry, step: step, progress: progress(for: entryIndex)))
    }
    
    private func startTrain() async {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                let speedEntry = speedEntry(for: entryIndex)
                
                train.state = .running
                
                // Set the speed without inertia to ensure the locomotive accelerates as fast as possible
                layout.setTrainSpeed(train, speedEntry.steps, inertia: false) {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    
    private func stopTrain() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [self] in
                do {
                    // Note: in practice, the train inertia must be set to true if the locomotive take some time to slow down,
                    // in order for BTrain to wait long enough for the locomotive to be stopped.
                    try layout.stopTrain(train.id) {
                        continuation.resume(returning: ())
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
