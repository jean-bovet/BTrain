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

protocol LayoutCreating {
    static var id: Identifier<Layout> { get }
    var name: String { get }
    func newLayout() -> Layout
}

final class LayoutFactory {

    static let DefaultSpeed: TrainSpeed.UnitKph = 70

    static let GlobalLayouts: [LayoutCreating] = [
        LayoutACreator(),
        LayoutBCreator(),
        LayoutCCreator(),
        LayoutDCreator(),
        LayoutECreator(),
        LayoutGCreator(),
        LayoutFCreator()
    ]

    static let GlobalLayoutIDs: [Identifier<Layout>] = {
        return GlobalLayouts.map { type(of: $0).id }
    }()
    
    static func globalLayoutName(_ id: Identifier<Layout>) -> String {
        return GlobalLayouts.filter { type(of: $0).id == id }.first!.name
    }
    
    static func createLayout(_ id: Identifier<Layout>) -> Layout {
        return GlobalLayouts.filter { type(of: $0).id == id }.first!.newLayout()
    }

    static func layoutFrom(_ routeString: String) -> Layout {
        return layoutFrom([routeString])
    }
    
    static func layoutFrom(_ routeStrings: [String]) -> Layout {
        let parser = LayoutParser(routeStrings)
        parser.parse()
        return parser.layout
    }
    
    static func stringFrom(_ layout: Layout, route: Identifier<Route>) -> String {
        var text = ""
        
        guard let route = layout.route(for: route, trainId: nil) else {
            return text
        }
        
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
                        
            if let trainId = block.train?.trainId,
               let train = layout.train(for: trainId),
                train.position == 0 {
                text += " " + stringFrom(train)
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
                if let trainId = block.train?.trainId,
                   let train = layout.train(for: trainId),
                    train.position == index + 1 {
                    text += " " + stringFrom(train)
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
    
    static func stringFrom(_ train: Train) -> String {
        if train.speed.kph == 0 {
            return "🛑🚂\(train.id)"
        } else {
            return "🚂\(train.id)"
        }
    }
}
