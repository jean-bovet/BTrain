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

struct TrainControlRouteView: View {
    
    struct RouteItem: Hashable {
        let name: String
        let routeId: Identifier<Route>
    }
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var train: Train
                
    var layout: Layout {
        document.layout
    }
    
    var selectedRouteDescription: String {
        var text = ""
        if let route = layout.route(for: train.routeId, trainId: train.id),
           let train = layout.train(for: train.id) {
            if let message = route.lastMessage {
                text = message
            } else {
                for (index, step) in route.blockSteps.enumerated() {
                    if !text.isEmpty {
                        text += "→"
                    }
                    
                    if let stepBlock = step as? RouteStep_Block {
                        if let block = layout.block(for: stepBlock.blockId) {
                            text += "\(block.name)"
                        } else {
                            text += "\(stepBlock.blockId)"
                        }
                    }
                    
                    if train.routeStepIndex == index {
                        // Indicate the block in the route where the train
                        // is currently located
                        text += "􀼮"
                    }
                }
            }
        }
        return text
    }
    
    var defaultRouteDescription: String {
        return "􀼮→"
    }
    
    var routeItems: [RouteItem] {
        return layout.manualRoutes.map { RouteItem(name: $0.name, routeId: $0.id) }
    }
        
    var automaticRouteId: Identifier<Route> {
        return Route.automaticRouteId(for: train.id)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Route:", selection: $train.routeId) {
                    Text("Automatic").tag(automaticRouteId as Identifier<Route>)
                    ForEach(routeItems, id:\.self) { item in
                        Text(item.name).tag(item.routeId as Identifier<Route>)
                    }
                }
                                    
                Spacer()
                
                if let route = layout.route(for: train.routeId, trainId: train.id) {
                    TrainControlRouteActionsView(document: document, train: train, route: route)
                        .disabled(!document.connected)
                }
            }
            if selectedRouteDescription.isEmpty {
                Text(defaultRouteDescription)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
            } else {
                Text(selectedRouteDescription)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TrainControlRouteView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())

    static var previews: some View {
        TrainControlRouteView(document: doc, train: doc.layout.trains[0])
    }
}
