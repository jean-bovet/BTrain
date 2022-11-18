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

struct TrainControlRemoveSheet: View {
    let layout: Layout
    let controller: LayoutController

    @ObservedObject var train: Train

    @State private var blockId: Identifier<Block>? = nil

    @State private var errorStatus: String?

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            if let block = layout.blocks[blockId] {
                Text("Remove \"\(train.name)\" from block \(block.name)?")
                    .fixedSize()
            } else if let blockId = blockId {
                Text("Remove \"\(train.name)\" from block \(blockId.uuid)?")
                    .fixedSize()
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

                Button("Remove") {
                    do {
                        try controller.remove(train: train)
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
        .onAppear {
            blockId = train.blockId
        }
    }
}

struct TrainControlRemoveSheet_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())

    static var previews: some View {
        TrainControlRemoveSheet(layout: doc.layout, controller: doc.layoutController, train: doc.layout.trains[0])
    }
}
