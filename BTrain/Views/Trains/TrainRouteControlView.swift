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

import SwiftUI

struct TrainRouteControlView: View {
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var train: Train

    @ObservedObject var route: Route

    @Binding var error: String?
    
    func reserveAll() throws {
        document.switchboard.state.triggerRedraw.toggle()
        for (index, step) in route.steps.enumerated() {
            if index+1 < route.steps.count {
                let nextStep = route.steps[index+1]
                try document.layout.reserve(train: train.id,
                                            fromBlock: step.blockId,
                                            toBlock: nextStep.blockId,
                                            direction: step.direction)
            }
        }
    }
    
    var body: some View {
        HStack {
            if document.debugMode {
                Button("Reserve All") {
                    do {
                        try reserveAll()
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            
            if route.enabled {
                Button("Stop") {
                    try? document.stop(train: train)
                }
            } else {
                Button("Start") {
                    do {
                        try document.start(train: train.id, withRoute: route.id, toBlockId: nil)
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct TrainRouteControlView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutACreator().newLayout())

    static var previews: some View {
        TrainRouteControlView(document: doc, train: doc.layout.trains[0], route: doc.layout.routes[0], error: .constant(""))
    }

}
