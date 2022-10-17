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

struct TrainControlMoveSheet: View {
    let layout: Layout
    let controller: LayoutController
    
    // Optional information resulting from dragging the train on the switchboard
    var trainDragInfo: SwitchBoard.State.TrainDragInfo?
            
    @ObservedObject var train: Train
    
    @State private var blockId: Identifier<Block>? = nil
    
    @State private var direction: Direction = .next
        
    @State private var routeDescription: String?
    
    @State private var errorStatus: String?

    @Environment(\.presentationMode) var presentationMode
    
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
                Text("Move \"\(train.name)\"")
                
                Picker("to block", selection: $blockId) {
                    ForEach(sortedBlockIds, id:\.self) { blockId in
                        if let block = layout.block(for: blockId) {
                            Text(block.nameForLocation).tag(blockId as Identifier<Block>?)
                        } else {
                            Text(blockId.uuid).tag(blockId as Identifier<Block>?)
                        }
                    }
                }
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
                    evaluateBestRoute(fromBlockId: trainDragInfo?.blockId ?? train.blockId, forDirection: nil)
                }

                Spacer()
            }
                        
            HStack {
                if let routeDescription = routeDescription {
                    Text("Route: \(routeDescription)")
                } else {
                    Text("No Route Found")
                }
                Spacer()
            }

            if let errorStatus = errorStatus {
                Text(errorStatus)
                    .foregroundColor(.red)
                    .fixedSize()
            }
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    self.presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.cancelAction)
                
                Button("Move") {
                    do {
                        if let selectedBlock = blockId {
                            let routeId = Route.automaticRouteId(for: train.id)
                            let destination = Destination(selectedBlock, direction: direction)
                            try controller.start(routeID: routeId, trainID: train.id, destination: destination)
                        }
                        errorStatus = nil
                        self.presentationMode.wrappedValue.dismiss()
                    } catch {
                        errorStatus = error.localizedDescription
                    }
                }
                .disabled(blockId == nil || routeDescription == nil)
                .keyboardShortcut(.defaultAction)
            }.padding([.top])
        }
        .onChange(of: blockId) { newValue in
            evaluateBestRoute(fromBlockId: blockId, forDirection: direction)
        }
        .onChange(of: direction) { newValue in
            evaluateBestRoute(fromBlockId: blockId, forDirection: direction)
        }
    }
    
    func evaluateBestRoute(fromBlockId: Identifier<Block>?, forDirection: Direction?) {
        if let block = layout.block(for: fromBlockId) {
            do {
                let result = try layout.bestRoute(ofTrain: train, toReachBlock: block, withDirection: forDirection)
                applySuggestedRoute(result)
                if forDirection == nil {
                    applySuggestedDirection(result)
                }
            } catch {
                BTLogger.error("Unable to retrieve the direction of the train: \(error.localizedDescription)")
            }
        }
    }
    
    func applySuggestedRoute(_ gp: GraphPath?) {
        if let gp = gp {
            let description = layout.routeDescription(for: train, steps: gp.elements.toBlockSteps)
            routeDescription = description
        } else {
            routeDescription = nil
        }
    }
    
    func applySuggestedDirection(_ gp: GraphPath?) {
        guard let gp = gp else {
            return
        }
        
        guard let lastElement = gp.elements.last else {
            return
        }
        
        if lastElement.entrySocket == Block.previousSocket {
            direction = .next
        } else {
            direction = .previous
        }
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

struct TrainControlMoveSheet_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    
    static var previews: some View {
        TrainControlMoveSheet(layout: doc.layout, controller: doc.layoutController, train: doc.layout.trains[0])
    }
    
}
