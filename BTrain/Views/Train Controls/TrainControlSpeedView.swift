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
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button(train.directionForward ? "􀄫" : "􀄪") {
                    document.layout.setLocomotiveDirection(train, forward: !train.directionForward)
                }
                .buttonStyle(.borderless)
                .help("Change Direction of Travel")
                                
                SpeedSlider(speed: speed) {
                    document.layout.setTrainSpeed(train, speed.requestedKph, speedLimit: false) { }
                }
            }.disabled(!document.connected || train.blockId == nil)
        }
    }
}

struct TrainControlView_Previews: PreviewProvider {
    
    static let doc: LayoutDocument = {
        let layout = LayoutLoop1().newLayout()
        return LayoutDocument(layout: layout)
    }()

    static var previews: some View {
        TrainControlSpeedView(document: doc, train: doc.layout.trains[0], speed: doc.layout.trains[0].speed)
    }
}
