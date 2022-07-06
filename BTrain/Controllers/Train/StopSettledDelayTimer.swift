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

/// A timer used to wait for the locomotive to fully come to a stop
///
/// When stopping a locomotive, we need to wait a bit more to ensure the locomotive
/// has effectively stopped physically on the layout. This is because we want to call back
/// the `completion` block only when the locomotive has stopped (otherwise, it might continue
/// to move and activate an unexpected feedback because the layout think it has stopped already).
/// There is unfortunately no way to know without ambiguity from the Digital Controller if the
/// train has stopped so this extra wait time can be configured in the UX, per locomotive, and
/// adjusted by the user depending on the locomotive speed inertia behavior.
protocol StopSettledDelayTimer {
    
    /// Schedules the timer for the specified train
    /// - Parameters:
    ///   - train: the train to wait to come to a full stop
    ///   - completed: true if the speed command has completed, false if it has been cancelled
    ///   - completion: the completion block to invoke when the timer fires
    func schedule(train: Train, completed: Bool, completion: @escaping (Bool) -> Void)
    
    /// Cancels the timer
    func cancel()
    
}

/// Default implementation of the settled timer
final class DefaultStopSettledDelayTimer: StopSettledDelayTimer {
    var timer: Timer?
    var block: ((Bool) -> Void)?
    
    func schedule(train: Train, completed: Bool, completion: @escaping (Bool) -> Void) {
        assert(block == nil)
        assert(timer == nil)

        block = { completed in
            completion(completed)
        }
        timer = Timer.scheduledTimer(withTimeInterval: train.speed.stopSettleDelay * BaseTimeFactor, repeats: false) { timer in
            self.block?(completed)
            self.block = nil
            self.timer = nil
        }
    }
    
    func cancel() {
        if let block = block {
            block(false)
        }
        block = nil
        timer?.invalidate()
        timer = nil
    }
}
