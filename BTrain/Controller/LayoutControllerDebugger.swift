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
import SwiftUI

final class LayoutControllerDebugger {
    
    @AppStorage("recordDiagnosticLogs") private var enabled = false
    
    struct Iterations {
        var iterations = [String]()
        
        mutating func add(_ ascii: String) -> Bool {
            if iterations.last == ascii {
                return false
            }
            iterations.append(ascii)
            return true
        }
    }
    
    private var routes = [Identifier<Route>:Iterations]()
    
    func record(layoutController: LayoutController, controllers: [TrainController]) {
        guard enabled else {
            return
        }
        
        let layout = layoutController.layout
        let producer = LayoutASCIIProducer(layout: layout)
        for controller in controllers {
            if let route = layout.route(for: controller.train.routeId, trainId: controller.train.id), !route.steps.isEmpty {
                if let s = try? producer.stringFrom(route: route) {
                    if routes.index(forKey: route.id) == nil {
                        routes[route.id] = Iterations()
                    }

                    let ascii = "\(route.id): "+s
                    if let result = routes[route.id]?.add(ascii), result {
                        BTLogger.debug("[LayoutController] "+ascii)
                    }
                }
            }
        }
    }

}
