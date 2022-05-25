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

// This class allows the monitoring of individual feedbacks
// on either side of the detection pulse.
final class FeedbackMonitor {
    
    private let layout: Layout
    private let interface: CommandInterface
    private var feedbackChangeUUID: UUID?
    
    struct Request {
        let completion: CompletionBlock
        let detected: Bool
        let feedbackId: Identifier<Feedback>
    }
    
    private var requests = [Request]()
        
    var pendingRequestCount: Int {
        return requests.count
    }
    
    init(layout: Layout, interface: CommandInterface) {
        self.layout = layout
        self.interface = interface
    }
    
    func start() {
        registerForFeedbackChanges()
    }
    
    func cancel() {
        requests.forEach { $0.completion() }
        requests.removeAll()
    }
    
    func stop() {
        unregisterForFeedbackChanges()
    }
    
    func waitForFeedback(_ feedbackId: Identifier<Feedback>, detected: Bool, completion: @escaping CompletionBlock) {
        requests.append(Request(completion: completion, detected: detected, feedbackId: feedbackId))
    }
    
    private func registerForFeedbackChanges() {
        feedbackChangeUUID = interface.register(forFeedbackChange: { [weak self] deviceID, contactID, value in
            guard let sSelf = self else {
                return
            }
            
            guard let feedback = sSelf.layout.feedbacks.find(deviceID: deviceID, contactID: contactID) else {
                return
            }
                            
            sSelf.process(feedback: feedback, detected: value == 1)
        })
    }
    
    private func process(feedback: Feedback, detected: Bool) {
        requests.filter { $0.feedbackId == feedback.id && $0.detected == detected }.forEach { $0.completion() }
        requests.removeAll(where: { $0.feedbackId == feedback.id && $0.detected == detected })
    }
    
    private func unregisterForFeedbackChanges() {
        if let feedbackChangeUUID = feedbackChangeUUID {
            interface.unregister(uuid: feedbackChangeUUID)
        }
    }

}
