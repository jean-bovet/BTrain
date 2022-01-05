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
// of a block is performed serialy, every 250ms.
// This is used to ensure commands sent to the Central Station
// are not clobbed together or sent too fast which would cause
// one event to be missed. This happens for example when
// changing the state of a crossing turnout, where two turnouts
// are changed at the same time.
final class ScheduledMessageQueue {

    typealias ExecutionBlock = ( (@escaping CompletionBlock) -> Void)

    typealias CompletionBlock = (() -> Void)

    static let delay = 0.250
    
    private var scheduledQueue = [ExecutionBlock]()

    private var executingQueue = [ExecutionBlock]()
    
    private var executing = false
    
    init() {
        scheduleSendData()
    }
    
    func schedule(block: @escaping ExecutionBlock) {
        scheduledQueue.append(block)
    }
        
    private func execute(block: @escaping ExecutionBlock) {
        guard !executing else {
            executingQueue.append(block)
            return
        }
        executing = true

        block() {
            DispatchQueue.main.async {
                self.executing = false
                
                if !self.executingQueue.isEmpty {
                    let data = self.executingQueue.removeFirst()
                    self.execute(block: data)
                }
            }
        }
    }
    
    private func scheduleSendData() {
        Timer.scheduledTimer(withTimeInterval: ScheduledMessageQueue.delay, repeats: true) { timer in
            if !self.scheduledQueue.isEmpty {
                let data = self.scheduledQueue.removeFirst()
                self.execute(block: data)
            }
        }
    }
}
