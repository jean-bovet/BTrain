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

final class LayoutASCIIProducer {
    
    let layout: Layout
    
    init(layout: Layout) {
        self.layout = layout
    }
    
    func stringFrom(route: Route) -> String {
        var text = ""
                
        for step in route.steps {
            guard let block = layout.block(for: step.blockId) else {
                fatalError("Unable to find block \(step.blockId)")
            }
            if step.direction == .previous {
                text += "!"
            }
            switch(block.category) {
            case .station:
                text += "{"
                if let reserved = block.reserved {
                    text += "r\(reserved.trainId)"
                    text += "{"
                }
                text += "\(block.id)"
            case .free, .sidingNext, .sidingPrevious:
                text += "["
                if let reserved = block.reserved {
                    text += "r\(reserved.trainId)"
                    text += "["
                }
                text += "\(block.id)"
            }
                        
            if let part = train(block, 0) {
                text += " " + part
            }

            for (index, feedback) in block.feedbacks.enumerated() {
                guard let f = layout.feedback(for: feedback.feedbackId) else {
                    fatalError("Unable to find feedback \(feedback.feedbackId)")
                }
                if f.detected {
                    text += " ≡"
                } else {
                    text += " ≏"
                }
                if let part = train(block, index+1) {
                    text += " " + part
                }
            }
            
            switch(block.category) {
            case .station:
                if block.reserved != nil {
                    text += " }} "
                } else {
                    text += " } "
                }
            case .free, .sidingNext, .sidingPrevious:
                if block.reserved != nil {
                    text += " ]] "
                } else {
                    text += " ] "
                }
            }
        }
        
        return text
    }
    
    func train(_ block: Block, _ position: Int) -> String? {
        guard let trainInstance = block.train else {
            return nil
        }
              
        guard let train = layout.train(for: trainInstance.trainId) else {
            return nil
        }

        if trainInstance.parts.isEmpty && train.position == position {
            return stringFrom(train)
        } else if let part = trainInstance.parts[position] {
            switch part {
            case .locomotive:
                return stringFrom(train)
            case .wagon:
                return "💺\(train.id)"
            }
        } else {
            return nil
        }
    }
    
    func stringFrom(_ train: Train) -> String {
        switch train.state {
        case .running:
            return "🚂\(train.id)"
        case .braking:
            return "🟨🚂\(train.id)"
        case .stopped:
            return "🛑🚂\(train.id)"
        }
    }
    
}
