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

// This class ensures that every scheduled execution
// of a block is performed serially, every x ms.
final class ScheduledMessageQueue {
    typealias ExecutionBlock = (@escaping CompletionBlock) -> Void

    struct ScheduledBlock {
        let priority: Bool
        let block: ExecutionBlock
    }

    private var scheduledQueue = [ScheduledBlock]()

    private var enabled = true
    private var executing = false

    // Default delay of 50ms between commands
    static let DefaultDelay = 50.0 / 1000.0

    var scheduledCount: Int {
        scheduledQueue.count
    }

    let delay: TimeInterval
    let name: String

    init(delay: TimeInterval = ScheduledMessageQueue.DefaultDelay * BaseTimeFactor, name: String) {
        self.delay = delay
        self.name = name
        MainThreadQueue.sync {
            scheduleSendData()
        }
    }

    func enable() {
        BTLogger.debug("􀐫 [\(name)] enable")
        executing = false
        enabled = true
    }

    func disable() {
        BTLogger.debug("􀐫 [\(name)] disable")
        enabled = false
        scheduledQueue.removeAll()
    }

    func schedule(priority: Bool = false, block: @escaping ExecutionBlock) {
        guard enabled else {
            return
        }

        let scheduledBlock = ScheduledBlock(priority: priority, block: block)
        if scheduledBlock.priority {
            scheduledQueue.insert(scheduledBlock, at: 0)
        } else {
            scheduledQueue.append(scheduledBlock)
        }
        printStats()
    }

    private func execute(scheduledBlock: ScheduledBlock) -> Bool {
        guard enabled else {
            return false
        }
        guard !executing else {
            return false
        }
        executing = true

        scheduledBlock.block {
            MainThreadQueue.sync {
                self.executing = false
                self.printStats()
            }
        }

        return true
    }

    private func scheduleSendData() {
        Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] _ in
            guard let sSelf = self else {
                return
            }
            if !sSelf.scheduledQueue.isEmpty {
                let scheduledBlock = sSelf.scheduledQueue.removeFirst()
                if sSelf.execute(scheduledBlock: scheduledBlock) == false {
                    // Schedule again the block if it could not be executed
                    sSelf.scheduledQueue.insert(scheduledBlock, at: 0)
                }
            }
        }
    }

    private func printStats() {
        BTLogger.debug("􀐫 [\(name)] \(scheduledQueue.count) scheduled")
    }
}
