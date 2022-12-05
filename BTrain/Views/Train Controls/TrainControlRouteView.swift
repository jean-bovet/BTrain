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
    @ObservedObject var document: LayoutDocument

    @ObservedObject var train: Train

    @Binding var trainRuntimeError: String?

    var layout: Layout {
        document.layout
    }

    var selectedRouteDescription: String {
        layout.routeDescription(for: train)
    }

    var automaticRouteId: Identifier<Route> {
        Route.automaticRouteId(for: train.id)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Picker("Route:", selection: $train.routeId) {
                    Text("Automatic").tag(automaticRouteId as Identifier<Route>)
                    ForEach(layout.fixedRoutes.sorted(by: {$0.name < $1.name}), id: \.self) { item in
                        Text(item.name).tag(item.id as Identifier<Route>)
                    }
                }.onChange(of: train.routeId) { _ in
                    updateRoute()
                }.disabled(train.scheduling != .unmanaged)

                Spacer()

                if let route = layout.route(for: train.routeId, trainId: train.id) {
                    HStack {
                        if train.scheduling == .unmanaged {
                            Button("Start") {
                                do {
                                    trainRuntimeError = nil
                                    try document.start(train: train.id, withRoute: route.id, destination: nil)
                                } catch {
                                    trainRuntimeError = error.localizedDescription
                                }
                            }.disabled(!document.power)
                        } else {
                            Button("Stop") {
                                route.lastMessage = nil
                                document.stop(train: train)
                            }

                            Button("Finish") {
                                route.lastMessage = nil
                                document.finish(train: train)
                            }.disabled(train.scheduling == .finishManaged || train.scheduling == .stopManaged || train.scheduling == .stopImmediatelyManaged)
                        }
                    }
                    .disabled(!document.connected)
                }
            }
            if selectedRouteDescription.isEmpty {
                Text(layout.defaultRouteDescription)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
            } else {
                ScrollView {
                    Text(selectedRouteDescription)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxHeight: 120)
            }
        }.onAppear {
            updateRoute()
        }.onReceive(NotificationCenter.default.publisher(for: .onRoutesUpdated), perform: { _ in
            updateRoute()
        })
    }

    func updateRoute() {
        try? document.layoutController.prepare(routeID: train.routeId, trainID: train.id)
    }
}

struct TrainControlRouteView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutLoop1().newLayout())

    static var previews: some View {
        TrainControlRouteView(document: doc, train: doc.layout.trains[0], trainRuntimeError: .constant(nil))
    }
}
