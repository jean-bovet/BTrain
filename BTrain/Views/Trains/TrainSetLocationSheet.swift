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

struct TrainSetLocationSheet: View {
    let layout: Layout
        
    @Environment(\.presentationMode) var presentationMode

    @ObservedObject var train: Train
        
    @State private var blockId: Identifier<Block>? = nil
    
    @State private var direction: Direction = .next
    
    @State private var errorStatus: String?

    var sortedBlockIds: [Identifier<Block>] {
        layout.blocks.sorted {
            $0.name < $1.name
        }.map {
            $0.id
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker("Block:", selection: $blockId) {
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
                    blockId = train.blockId
                }
                
                Picker("Direction:", selection: $direction) {
                    ForEach(Direction.allCases, id:\.self) { direction in
                        Text(direction.description).tag(direction)
                    }
                }
                .fixedSize()
                .labelsHidden()
                .onAppear {
                    do {
                        direction = try layout.directionDirectionInBlock(train)
                    } catch {
                        BTLogger.error("Unable to retrieve the direction of the train: \(error.localizedDescription)")
                    }
                }
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
                
                Button("OK") {
                    do {
                        if let selectedBlock = blockId {
                            try layout.setTrain(train.id, toBlock: selectedBlock, position: .end, direction: direction)
                        }
                        errorStatus = nil
                        self.presentationMode.wrappedValue.dismiss()
                    } catch {
                        errorStatus = error.localizedDescription
                    }
                }.keyboardShortcut(.defaultAction)
            }.padding()
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

struct TrainSetLocationView_Previews: PreviewProvider {
    static let layout = LayoutCCreator().newLayout()

    static var previews: some View {
        TrainSetLocationSheet(layout: layout, train: layout.mutableTrains[0])
    }

}
