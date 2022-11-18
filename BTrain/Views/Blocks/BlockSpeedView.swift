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

struct BlockSpeedView: View {
    @ObservedObject var block: Block

    var body: some View {
        Form {
            UndoProvider($block.brakingSpeed) { speed in
                TextField("Braking:", value: speed, format: .number, prompt: Text("\(LayoutFactory.DefaultBrakingSpeed)"))
                    .unitStyle("kph")
            }

            UndoProvider($block.speedLimit) { speedLimit in
                Picker("Speed Limit:", selection: speedLimit) {
                    ForEach(Block.SpeedLimit.allCases, id: \.self) { speedLimit in
                        Text(speedLimit.rawValue).tag(speedLimit as Block.SpeedLimit)
                    }
                }.fixedSize()
            }
        }
    }
}

struct BlockSpeedView_Previews: PreviewProvider {
    static var previews: some View {
        BlockSpeedView(block: Block())
    }
}
