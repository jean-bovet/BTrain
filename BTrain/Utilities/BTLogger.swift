// Copyright 2021 Jean Bovet
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

final class BTLogger {
    
    static func error(_ msg: String) {
        print("[Error] \(msg)")
    }
    
    static func debug(_ msg: String) {
        print("[Debug] \(msg)")
    }
    
    static func debug(_ msg: String, _ layout: Layout, _ train: ITrain? = nil) {
        var attributes = [String]()
        attributes.append("\(layout)")
        if let train = train {
            attributes.append("\(train.name)")
        }
        if let routeId = train?.routeId, let route = layout.route(for: routeId, trainId: train?.id) {
            attributes.append("\(route.name)")
        } else {
            attributes.append("No Route")
        }
        if let train = train, let cb = layout.currentBlock(train: train) {
            attributes.append(attributesFor(block: cb, layout: layout))
        }
        if let train = train, let nb = layout.nextBlock(train: train) {
            attributes.append(attributesFor(block: nb, layout: layout))
        }
        print("[\(attributes.joined(separator: "|"))] \(msg)")
    }

    static func attributesFor(block: IBlock, layout: Layout) -> String {
        var info = "\(block.name)"
        if let reserved = block.reserved {
            info += ",r=\(reserved)"
        }
        if let trainInstance = block.train {
            if let train = layout.train(for: trainInstance.trainId) {
                info += ",t=\(train.name)"
            }
            if let t = layout.train(for: trainInstance.trainId) {
                info += "@\(t.position)"
            }
            if trainInstance.direction == .next {
                info += ">"
            } else {
                info += "<"
            }
        }
        return info
    }
}
