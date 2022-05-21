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
        
    var body: some View {
        HStack {
            if train.scheduling == .unmanaged {
                Button("Start") {
                    do {
                        train.runtimeInfo = nil
                        try document.start(train: train.id, withRoute: route.id, destination: nil)
                    } catch {
                        train.runtimeInfo = error.localizedDescription
                    }
                }
            } else {
                Button("Stop") {
                    route.lastMessage = nil
                    document.stop(train: train)
                }.disabled(train.scheduling == .stopManaged)
                
                Button("Finish") {
                    route.lastMessage = nil
                    document.finish(train: train)
                }.disabled(train.scheduling == .finishManaged || train.scheduling == .stopManaged)
            }
        }
    }
}

struct TrainControlRouteActionsView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())

    static var previews: some View {
        TrainControlRouteActionsView(document: doc, train: doc.layout.trains[0], route: doc.layout.routes[0])
    }

}
