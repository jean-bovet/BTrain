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
import Combine

/// This class manages and executs layout scripts, which are script that orchestrate one or more
/// routes and trains together.
final class LayoutScriptConductor {
    
    let layout: Layout
    weak var layoutController: LayoutController?
    
    internal init(layout: Layout) {
        self.layout = layout
    }
    
    private var anyCancellables = [AnyCancellable]()
    
    func start(_ scriptId: Identifier<LayoutScript>) {
        guard let script = layout.layoutScripts[scriptId] else {
            return
        }
        
        for command in script.commands {
            start(trainId: command.train, routeScriptId: command.route)
        }
//        addListener(toTrainNamed: "Cargo 474") { train, scheduling in
//
//        }
//        addListener(toTrainNamed: "S-Bahn") { train, scheduling in
//
//        }
//        addListener(toTrainNamed: "TGV") { [weak self] train, scheduling in
//            if scheduling == .unmanaged {
//                self?.start(trainNamed: "Cargo 474", routeNamed: "S2 Loop")
//            }
//        }
//
//        start(trainNamed: "TGV", routeNamed: "HS_T7 Loop")
//        start(trainNamed: "S-Bahn", routeNamed: "S3 Loop")
    }
    
    func stop() {
        // TODO: stop
    }
    
//    func addListener(toTrainNamed trainName: String, callback: @escaping (Train, Train.Schedule) -> Void)  {
//        let train = train(named: trainName)
//        anyCancellables.append(train.$scheduling.dropFirst().removeDuplicates().sink { schedule in
//            print("** \(train.name): \(schedule)")
//            callback(train, schedule)
//        })
//    }
    
    func start(trainId: Identifier<Train>?, routeScriptId: Identifier<RouteScript>?) {
        guard let route = layout.routes.first(where: {$0.id.uuid == routeScriptId?.uuid}) else {
            return
        }
        
        guard let train = layout.trains[trainId] else {
            return
        }
        
        do {
            try layoutController?.start(routeID: route.id, trainID: train.id)
        } catch {
            // TODO: display something?
        }
    }
    
}
