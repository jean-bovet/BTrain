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

extension LayoutController {
    func dumpAll() {
        var text = "*******************************************"
        text += "\nEnabled Trains:"
        for train in layout.trains.elements.filter({ $0.enabled }) {
            text += "\n " + LayoutController.attributesFor(train: train, layout: layout)
        }
        text += "\nInteresting Blocks:"
        for block in layout.blocks.elements.filter({ $0.enabled && ($0.reservation != nil || $0.trainInstance != nil) }) {
            text += "\n " + LayoutController.attributesFor(block: block, layout: layout)
        }
        text += "\nRoutes:"
        for route in layout.routes {
            text += "\n " + LayoutController.attributesFor(route: route, layout: layout)
        }
        text += "*******************************************"
        BTLogger.router.error("\(text, privacy: .public)")
    }

    static func attributesFor(route: Route, layout _: Layout) -> String {
        var info = "\(route.name)-[\(route.id)]"
        switch route.mode {
        case let .automaticOnce(destination: destination):
            info += " (automatic once to \(destination.blockId), direction \(String(describing: destination.direction))"
        case .automatic:
            info += " (automatic endless mode)"
        case .fixed:
            info += " (fixed)"
        }
        info += ". \(route.steps.count) steps: "
        for step in route.steps {
            info += step.description
        }
        return info
    }

    static func attributesFor(train: Train, layout: Layout) -> String {
        var info = "\(train)"
        if let route = layout.route(for: train.routeId, trainId: train.id) {
            info += ": route \(route.name) at step \(train.routeStepIndex)"
        } else {
            info += ": no route assigned"
        }
        if let cb = train.block {
            info += ", block \(cb.name) at position \(train.positions)"
        }
        if let loc = train.locomotive {
            info += ", speed \(loc.speed)"
        } else {
            info += ", no loc"
        }
        info += ", scheduling \(train.scheduling)"
        info += ", state \(train.state)"
        return info
    }

    static func attributesFor(block: Block, layout: Layout) -> String {
        var info = "\(block.name)-[\(block.id)]"
        if let reserved = block.reservation, let train = layout.trains[reserved.trainId] {
            info += ", reserved for \(train.name)-\(reserved.direction)"
        }
        if let trainInstance = block.trainInstance {
            if let train = layout.trains[trainInstance.trainId] {
                info += ", train \(train.name)"
            }
            if let t = layout.trains[trainInstance.trainId] {
                info += " at position \(t.positions)"
            }
            if trainInstance.direction == .next {
                info += ", direction forward"
            } else {
                info += ", direction backward"
            }
        }
        return info
    }
}
