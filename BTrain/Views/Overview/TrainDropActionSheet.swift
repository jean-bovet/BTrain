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

extension Layout {
    func setTrain(info: SwitchBoard.State.TrainDragInfo, direction: Direction) throws {
        // Direction is nil so the train will preserve its direction
        try free(trainID: info.trainId, removeFromLayout: true)
        try setTrainToBlock(info.trainId, info.blockId, direction: direction)
    }
}

extension LayoutController {
    func routeTrain(info: SwitchBoard.State.TrainDragInfo, direction: Direction) throws {
        let routeId = Route.automaticRouteId(for: info.trainId)
        let destination = Destination(info.blockId, direction: direction)
        try start(routeID: routeId, trainID: info.trainId, destination: destination)
    }
}

struct TrainDropActionSheet: View {
    
    let layout: Layout
    let trainDragInfo: SwitchBoard.State.TrainDragInfo
    let controller: LayoutController
    @State private var direction: Direction = .next

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack {
                if let block = layout.block(for: trainDragInfo.blockId) {
                    Text("Block \(block.name)")
                }
                
                Picker("Direction:", selection: $direction) {
                    ForEach(Direction.allCases, id:\.self) { direction in
                        Text(direction.description).tag(direction)
                    }
                }
                .fixedSize()
                .labelsHidden()
                
                Spacer()
            }

            Divider()

            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)

                Spacer().fixedSpace()
                
                Button("Set Train") {
                    try? layout.setTrain(info: trainDragInfo, direction: direction)
                    presentationMode.wrappedValue.dismiss()
                }

                Button("Move Train") {
                    try? controller.routeTrain(info: trainDragInfo, direction: direction)
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}

struct TrainDropActionSheet_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutCCreator().newLayout())
    
    static var previews: some View {
        TrainDropActionSheet(layout: doc.layout,
                             trainDragInfo: .init(trainId: .init(uuid: "1"), blockId: .init(uuid: "b1")),
                             controller: doc.layoutController)
    }
}
