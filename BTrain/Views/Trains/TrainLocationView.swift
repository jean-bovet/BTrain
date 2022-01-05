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

struct TrainLocationView: View {
    
    @ObservedObject var layout: Layout
        
    @ObservedObject var train: Train
    
    @State private var errorStatus: String?
    
    @State private var setTrainLocationSheet = false
    
    var trainLocation: String {
        if let blockId = train.blockId, let block = layout.block(for: blockId) {
            return "\(block.name)"
        } else {
            return "-"
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                if train.blockId == nil {
                    Button("Set Train Location 􀅄") {
                        setTrainLocationSheet.toggle()
                    }
                    Spacer()
                } else {
                    Text("Location: \(trainLocation)")
                    
                    Spacer()

                    Button() {
                        setTrainLocationSheet.toggle()
                    } label: {
                        Image(systemName: "arrow.down.to.line.compact")
                    }
                    .help("Assign Train to a Block")
                    .buttonStyle(.borderless)
                    
                    Button() {
                        do {
                            try layout.free(trainID: train.id, removeFromLayout: true)
                            errorStatus = nil
                        } catch {
                            errorStatus = error.localizedDescription
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .help("Remove Train from its Block")
                    .buttonStyle(.borderless)
                    .disabled(train.blockId == nil)
                }
            }
            if let errorStatus = errorStatus {
                Text(errorStatus)
                    .foregroundColor(.red)
            }
        }.sheet(isPresented: $setTrainLocationSheet) {
            TrainSetLocationSheet(layout: layout, train: train)
                .padding()
        }
    }
}

struct TrainLocationView_Previews: PreviewProvider {
    
    static let layout = LayoutCCreator().newLayout()

    static var previews: some View {
        TrainLocationView(layout: layout, train: layout.mutableTrains[0])
    }
}
