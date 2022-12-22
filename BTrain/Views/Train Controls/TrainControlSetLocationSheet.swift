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
    let doc: LayoutDocument

    @ObservedObject var train: Train

    @State private var blockId: Identifier<Block>?

    @State private var direction: Direction = .next

    @State private var errorStatus: String?

    @Environment(\.presentationMode) var presentationMode

    var selectedBlockName: String {
        if let block = layout.blocks[blockId] {
            return block.name
        } else {
            return "?"
        }
    }

    var body: some View {
        VStack {
            HStack {
                Text("Set \"\(train.name)\" to")
                    .fixedSize()

                BlockPicker(layout: layout, blockId: $blockId)
                    .onAppear {
                        blockId = train.block?.id
                        direction = train.block?.trainInstance?.direction ?? .next
                    }

                Picker("with direction", selection: $direction) {
                    ForEach(Direction.allCases, id: \.self) { direction in
                        Text(direction.description).tag(direction)
                    }
                }
                .help("This is the direction of travel of the train relative to \(selectedBlockName)")
                .fixedSize()

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

                Button("Set") {
                    do {
                        if let selectedBlock = blockId {
                            try controller.setupTrainToBlock(train, selectedBlock, naturalDirectionInBlock: direction)
                            doc.simulator.trainPositionChangedManually(train: train)
                            controller.redrawSwitchboard()
                        }
                        errorStatus = nil
                        self.presentationMode.wrappedValue.dismiss()
                    } catch {
                        errorStatus = error.localizedDescription
                    }
                }
                .disabled(blockId == nil)
                .keyboardShortcut(.defaultAction)
            }.padding([.top])
        }
    }
}

struct TrainControlSetLocationSheet_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        TrainControlSetLocationSheet(layout: doc.layout, controller: doc.layoutController, doc: doc, train: doc.layout.trains[0])
    }
}
