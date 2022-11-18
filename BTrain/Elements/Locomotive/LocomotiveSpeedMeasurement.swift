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
final class LocomotiveSpeedMeasurement {
    let layout: Layout
    let executor: LayoutController
    let interface: CommandInterface
    let loc: Locomotive
    let speedManager: LocomotiveSpeedManager

    let speedEntries: Set<LocomotiveSpeed.SpeedTableEntry.ID>
    let feedbackA: Identifier<Feedback>
    let feedbackB: Identifier<Feedback>
    let feedbackC: Identifier<Feedback>
    let distanceAB: Double
    let distanceBC: Double

    let feedbackMonitor: FeedbackMonitor

    // True if the measurement is done in the simulator,
    // which is going to affect some delays after stopping the locomotive
    let simulator: Bool

    private var entryIndex = 0

    // Direction of travel of the locomotive:
    // - If true, the locomotive is moving towards feedback A, B and then C.
    // - If false, the locomotive is moving towards feedback C, B and then A.
    private var forward = true

    private var task: Task<Void, Error>?

    enum CallbackStep {
        case locomotiveStarted
        case feedbackA
        case feedbackB
        case feedbackC
        case locomotiveStopped
        case locomotiveDirectionToggle
        case done
    }

    struct CallbackInfo {
        let speedEntry: LocomotiveSpeed.SpeedTableEntry
        let step: CallbackStep
        let progress: Double
    }

    init(layout: Layout, executor: LayoutController, interface: CommandInterface, loc: Locomotive,
         speedEntries: Set<LocomotiveSpeed.SpeedTableEntry.ID>,
         feedbackA: Identifier<Feedback>, feedbackB: Identifier<Feedback>, feedbackC: Identifier<Feedback>,
         distanceAB: Double, distanceBC: Double, simulator: Bool = false)
    {
        self.layout = layout
        self.executor = executor
        self.interface = interface
        self.loc = loc
        speedManager = LocomotiveSpeedManager(loc: loc, interface: interface, speedChanged: nil)
        self.speedEntries = speedEntries
        self.feedbackA = feedbackA
        self.feedbackB = feedbackB
        self.feedbackC = feedbackC
        self.distanceAB = distanceAB
        self.distanceBC = distanceBC
        feedbackMonitor = FeedbackMonitor(layout: layout, interface: interface)
        self.simulator = simulator
    }

    func start(callback: @escaping (CallbackInfo) -> Void) {
        if let task = task {
            log("Cancel already existing task")
            task.cancel()
        }

        // The measurement always start with the locomotive moving "forward" towards feedback A, B and then C.
        forward = true
        entryIndex = 0

        executor.enabled = false
        feedbackMonitor.start()

        task = Task {
            do {
                try await run(callback: callback)
                BTLogger.debug("Speed measurement task completed")
            } catch is CancellationError {
                BTLogger.error("Speed measurement task has been cancelled")
            } catch {
                BTLogger.error("Speed measurement task error: \(error)")
            }
            executor.enabled = true
        }
    }

    func cancel() {
        if let task = task {
            task.cancel()
        } else {
            BTLogger.warning("Unable to cancel speed measurement task because the task handle is nil")
        }

        feedbackMonitor.cancel()
        feedbackMonitor.stop()
    }

    func done() {
        feedbackMonitor.stop()
    }

    private func log(_ msg: String) {
        BTLogger.debug("􀍾 \(msg)")
    }

    private func run(callback: @escaping (CallbackInfo) -> Void) async throws {
        log("Start measuring \(loc)")
        while !Task.isCancelled {
            try await measure(callback: callback)
            try Task.checkCancellation()
            if isFinished(for: entryIndex + 1) {
                try invokeCallback(.done, callback)
                done()
                log("Done measuring \(loc)")
                break
            } else {
                entryIndex += 1
            }
        }

        if Task.isCancelled {
            try await stopLocomotive()
        }
    }

    private func measure(callback: @escaping (CallbackInfo) -> Void) async throws {
        await startLocomotive()
        try invokeCallback(.locomotiveStarted, callback)

        let feedbacks: [(Identifier<Feedback>, CallbackStep)]
        if forward {
            feedbacks = [(feedbackA, .feedbackA), (feedbackB, .feedbackB), (feedbackC, .feedbackC)]
        } else {
            feedbacks = [(feedbackC, .feedbackC), (feedbackB, .feedbackB), (feedbackA, .feedbackA)]
        }

        try await waitForFeedback(feedbacks[0].0)
        try invokeCallback(feedbacks[0].1, callback)

        try await waitForFeedback(feedbacks[1].0)
        let t0 = Date()
        try invokeCallback(feedbacks[1].1, callback)

        try await waitForFeedback(feedbacks[2].0)
        let t1 = Date()
        try invokeCallback(feedbacks[2].1, callback)

        try await waitForFeedback(feedbacks[2].0, detected: false)

        try await stopLocomotive()
        try invokeCallback(.locomotiveStopped, callback)

        DispatchQueue.main.sync {
            storeMeasurement(t0: t0, t1: t1, distance: forward ? distanceBC : distanceAB)
        }

        if !simulator, !Task.isCancelled {
            // Wait a bit before toggling the locomotive direction because a locomotive might still
            // not be fully stopped. Although stopLocomotive() waits until the locomotive has stopped (from a command
            // control point of view), some locomotive still need some time to stop fully.
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        try await toggleLocomotiveDirection()
        try invokeCallback(.locomotiveDirectionToggle, callback)
    }

    private func invokeCallback(_ step: CallbackStep, _ callback: @escaping (CallbackInfo) -> Void) throws {
        try Task.checkCancellation()

        log("Completed step \(step)")
        let speedEntry = speedEntry(for: entryIndex)
        callback(.init(speedEntry: speedEntry, step: step, progress: progress(for: entryIndex)))
    }

    private func startLocomotive() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                let speedEntry = speedEntry(for: entryIndex)

                // Set the speed without inertia to ensure the locomotive accelerates as fast as possible
                setLocomotiveSpeed(speedEntry.steps, acceleration: LocomotiveSpeedAcceleration.Acceleration.none) { _ in
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func stopLocomotive() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [self] in
                // Note: the locomotive inertia must be set to true if the locomotive take some time to slow down,
                // in order for BTrain to wait long enough for the locomotive to be stopped.
                setLocomotiveSpeed(.zero) { _ in
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func setLocomotiveSpeed(_ steps: SpeedStep, acceleration: LocomotiveSpeedAcceleration.Acceleration? = nil, completion: @escaping CompletionCancelBlock) {
        loc.speed.requestedSteps = steps
        if let acceleration = acceleration {
            speedManager.changeSpeed(acceleration: acceleration, completion: completion)
        } else {
            speedManager.changeSpeed(completion: completion)
        }
    }

    private func toggleLocomotiveDirection() async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async { [self] in
                self.forward.toggle()

                executor.setLocomotiveDirection(loc, forward: !loc.directionForward) {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func waitForFeedback(_ feedbackId: Identifier<Feedback>, detected: Bool = true) async throws {
        try Task.checkCancellation()
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                feedbackMonitor.waitForFeedback(feedbackId, detected: detected) {
                    continuation.resume()
                }
            }
        }
    }

    private func storeMeasurement(t0: Date, t1: Date, distance: Double) {
        let duration = t1.timeIntervalSince(t0)
        let speed = LayoutSpeed.speedToMove(distance: distance, forDuration: duration)

        let entry = speedEntry(for: entryIndex)
        setSpeedEntry(.init(steps: entry.steps, speed: speed), for: entryIndex)
    }

    private func speedEntry(for entryIndex: Int) -> LocomotiveSpeed.SpeedTableEntry {
        let entries = speedEntries.sorted()
        let speedTableIndex = Int(entries[entryIndex])
        let speedEntry = loc.speed.speedTable[speedTableIndex]
        return speedEntry
    }

    private func setSpeedEntry(_ speedEntry: LocomotiveSpeed.SpeedTableEntry, for entryIndex: Int) {
        let entries = speedEntries.sorted()
        let speedTableIndex = Int(entries[entryIndex])
        loc.speed.speedTable[speedTableIndex] = speedEntry
    }

    private func progress(for entryIndex: Int) -> Double {
        let progress = Double(entryIndex + 1) / Double(speedEntries.count)
        return progress
    }

    private func isFinished(for entryIndex: Int) -> Bool {
        entryIndex >= speedEntries.count
    }
}
