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

struct TrainControlSetLocationSheet: View {
    let layout: Layout
    let controller: LayoutController
    
    // Optional information resulting from dragging the train on the switchboard
    var trainDragInfo: SwitchBoard.State.TrainDragInfo?
        
    @ObservedObject var train: Train
    
    @State private var blockId: Identifier<Block>? = nil
    
    @State private var direction: Direction = .next
    
    @State private var wagonsPushedByLocomotive = false
    
    @State private var errorStatus: String?
    
    @Environment(\.presentationMode) var presentationMode

    enum Action {
        case set
        case move
    }
    
    @State private var action: Action = .set
    
    var sortedBlockIds: [Identifier<Block>] {
        layout.blocks.sorted {
            $0.name < $1.name
        }.map {
            $0.id
        }
    }
    
    var selectedBlockName: String {
        if let block = layout.block(for: blockId) {
            return block.name
        } else {
            return "?"
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker("Action:", selection: $action) {
                    Text("Set").tag(Action.set)
                    Text("Move").tag(Action.move)
                }
                .fixedSize()
                .labelsHidden()
                
                Text("\"\(train.name)\"")
                
                Picker("to block", selection: $blockId) {
                    ForEach(sortedBlockIds, id:\.self) { blockId in
                        if let block = layout.block(for: blockId) {
                            Text(block.nameForLocation).tag(blockId as Identifier<Block>?)
                        } else {
                            Text(blockId.uuid).tag(blockId as Identifier<Block>?)
                        }
                    }
                }
                .fixedSize()
                .onAppear {
                    if let trainDragInfo = trainDragInfo {
                        blockId = trainDragInfo.blockId
                    } else {
                        blockId = train.blockId
                    }
                }
                
                Picker("with direction", selection: $direction) {
                    ForEach(Direction.allCases, id:\.self) { direction in
                        Text(direction.description).tag(direction)
                    }
                }
                .help("This is the direction of travel of the train relative to \(selectedBlockName)")
                .fixedSize()
                .onAppear {
                    do {
                        direction = try layout.directionDirectionInBlock(train)
                    } catch {
                        BTLogger.error("Unable to retrieve the direction of the train: \(error.localizedDescription)")
                    }
                }
            }
            
            HStack {
                Toggle("Wagons Pushed by the Locomotive", isOn: $wagonsPushedByLocomotive)
                    .disabled(action == .move)
                    .onAppear {
                        wagonsPushedByLocomotive = train.wagonsPushedByLocomotive
                    }
                Spacer()
            }
            
            if let errorStatus = errorStatus {
                Text(errorStatus)
                    .foregroundColor(.red)
            }
            HStack {
                Spacer()
                
                Button("Cancel") {
                    self.presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)
                
                Button(action == .set ? "Set" : "Move") {
                    do {
                        if let selectedBlock = blockId {
                            if action == .set {
                                train.wagonsPushedByLocomotive = wagonsPushedByLocomotive
                                try controller.setTrain(trainId: train.id, blockId: selectedBlock, direction: direction)
                            } else {
                                try controller.routeTrain(trainId: train.id, blockId: selectedBlock, direction: direction)
                            }
                        }
                        errorStatus = nil
                        self.presentationMode.wrappedValue.dismiss()
                    } catch {
                        errorStatus = error.localizedDescription
                    }
                }
                .disabled(blockId == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
}

extension LayoutController {

    func setTrain(trainId: Identifier<Train>, blockId: Identifier<Block>, direction: Direction) throws {
        try layout.setTrainToBlock(trainId, blockId, position: .end, direction: direction)
        _ = run()
    }

    func routeTrain(trainId: Identifier<Train>, blockId: Identifier<Block>, direction: Direction) throws {
        let routeId = Route.automaticRouteId(for: trainId)
        let destination = Destination(blockId, direction: direction)
        try start(routeID: routeId, trainID: trainId, destination: destination)
    }
}

private extension Block {
    var nameForLocation: String {
        let name: String
        if category == .station {
            name = "\(self.name) - Station"
        } else {
            name = self.name
        }
        return name
    }
}

struct TrainControlSetLocationSheet_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutCCreator().newLayout())
    
    static var previews: some View {
        TrainControlSetLocationSheet(layout: doc.layout, controller: doc.layoutController, train: doc.layout.trains[0])
    }
    
}
