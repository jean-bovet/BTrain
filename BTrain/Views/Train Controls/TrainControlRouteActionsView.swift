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

struct TrainControlRouteActionsView: View {
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var train: Train

    @ObservedObject var route: Route

    @Binding var error: String?
        
    var body: some View {
        HStack {
            if document.showDebugModeControls {
                Button("Reserve Blocks") {
                    do {
                        try document.layout.reserveBlocksForTrainLength(train: train)
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            
            if train.scheduling == .stopped {
                Button("Start") {
                    do {
                        try document.start(train: train.id, withRoute: route.id, destination: nil)
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            } else {
                Button("Stop") {
                    do {
                        try document.stop(train: train)
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
                Button("Finish") {
                    do {
                        try document.finish(train: train)
                        self.error = nil
                    } catch {
                        self.error = error.localizedDescription
                    }
                }.disabled(train.scheduling == .finishing)
            }
        }
    }
}

struct TrainControlRouteActionsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutACreator().newLayout())

    static var previews: some View {
        TrainControlRouteActionsView(document: doc, train: doc.layout.trains[0], route: doc.layout.routes[0], error: .constant(""))
    }

}
