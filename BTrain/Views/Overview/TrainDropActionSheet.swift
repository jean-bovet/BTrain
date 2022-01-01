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

import SwiftUI

extension Layout {
    func moveTrain(info: SwitchBoard.State.TrainDragInfo) throws {
        // Direction is nil so the train will preserve its direction
        try free(trainID: info.trainId)
        try setTrain(info.trainId, toBlock: info.blockId, position: .custom(value: info.position), direction: nil)
    }
}

extension LayoutCoordinator {
    func routeTrain(info: SwitchBoard.State.TrainDragInfo) throws {
        let routeId = Route.automaticRouteId(for: info.trainId)
        try start(routeID: routeId, trainID: info.trainId, toBlockId: info.blockId)
    }
}

struct TrainDropActionSheet: View {
    
    let layout: Layout
    let trainDragInfo: SwitchBoard.State.TrainDragInfo
    let coordinator: LayoutCoordinator
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Button("Set Train") {
                try? layout.moveTrain(info: trainDragInfo)
                presentationMode.wrappedValue.dismiss()
            }.keyboardShortcut(.defaultAction)

            Button("Move Train") {
                try? coordinator.routeTrain(info: trainDragInfo)
                presentationMode.wrappedValue.dismiss()
            }

            Divider()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }.keyboardShortcut(.cancelAction)
        }
    }
}

struct TrainDropActionSheet_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutCCreator().newLayout())
    
    static var previews: some View {
        TrainDropActionSheet(layout: doc.layout,
                             trainDragInfo: .init(trainId: .init(uuid: "1"), blockId: .init(uuid: "b1"), position: 0),
                             coordinator: doc.coordinator!)
    }
}
