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

struct TrainControlSpeedView: View {
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var train: Train
    @ObservedObject var speed: TrainSpeed

    func trainDirectionToggle() {
        do {
            document.layout.setLocomotiveDirection(train, forward: !train.directionForward)
            try document.layout.toggleTrainDirectionInBlock(train)
            train.runtimeInfo = nil
        } catch {
            train.runtimeInfo = error.localizedDescription
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button {
                    trainDirectionToggle()
                } label: {
                    if train.directionForward {
                        Image(systemName: "arrowtriangle.right.fill")
                    } else {
                        Image(systemName: "arrowtriangle.left.fill")
                    }
                }.buttonStyle(.borderless)
                                
                SpeedSlider(speed: speed) {
                    document.layout.setTrainSpeed(train, speed.requestedKph) { }
                }
            }.disabled(!document.connected || train.blockId == nil)
        }
    }
}

struct TrainControlView_Previews: PreviewProvider {
    
    static let doc: LayoutDocument = {
        let layout = LayoutACreator().newLayout()
        return LayoutDocument(layout: layout)
    }()

    static var previews: some View {
        TrainControlSpeedView(document: doc, train: doc.layout.trains[0], speed: doc.layout.trains[0].speed)
    }
}
