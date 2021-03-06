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

struct TrainControlLocationView: View {
    
    let controller: LayoutController
    
    @ObservedObject var layout: Layout
        
    @ObservedObject var train: Train
        
    @State private var setTrainLocationSheet = false
    @State private var moveTrainLocationSheet = false
    @State private var removeTrainSheet = false

    var body: some View {
        VStack {
            HStack {
                HStack {
                    Text("Location:")
                        .font(Font.body.weight(.medium))
                    
                    if let blockId = train.blockId, let block = layout.block(for: blockId) {
                        Text("\(block.name)")
                        
                        Spacer()
                        
                        Button("􀅄") {
                            setTrainLocationSheet.toggle()
                        }
                        .help("Set Location")
                        .buttonStyle(.borderless)
                        
                        Button("􀅂") {
                            moveTrainLocationSheet.toggle()
                        }
                        .help("Move Train")
                        .buttonStyle(.borderless)
                        
                        Button("􀄨") {
                            removeTrainSheet.toggle()
                        }
                        .help("Remove Train")
                        .buttonStyle(.borderless)
                    } else {
                        Button("Set Location 􀅄") {
                            setTrainLocationSheet.toggle()
                        }.help("Set Location")
                    }
                }

                Spacer()
            }
        }.sheet(isPresented: $setTrainLocationSheet) {
            TrainControlSetLocationSheet(layout: layout, controller: controller, actionSet: .setOnly, train: train)
                .padding()
        }.sheet(isPresented: $moveTrainLocationSheet) {
            TrainControlSetLocationSheet(layout: layout, controller: controller, actionSet: .moveOrSet, train: train)
                .padding()
        }.sheet(isPresented: $removeTrainSheet) {
            TrainControlSetLocationSheet(layout: layout, controller: controller, actionSet: .removeOnly, train: train)
                .padding()
        }
    }
}

struct TrainControlLocationView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
    static let doc2: LayoutDocument = {
       let doc = LayoutDocument(layout: LayoutLoop2().newLayout())
        doc.layout.trains[0].blockId = doc.layout.blockIds[0]
        return doc
    }()

    static var previews: some View {
        Group {
            TrainControlLocationView(controller: doc.layoutController, layout: doc.layout, train: doc.layout.trains[0])
            TrainControlLocationView(controller: doc2.layoutController, layout: doc2.layout, train: doc2.layout.trains[0])
        }
    }
}
