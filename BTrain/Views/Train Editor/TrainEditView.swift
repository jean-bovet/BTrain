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

struct TrainEditView: View {
    
    let layout: Layout
    @ObservedObject var train: Train
    let trainIconManager: TrainIconManager

    var body: some View {
        Form {
            Picker("Decoder:", selection: $train.addressDecoderType) {
                ForEach(DecoderType.allCases, id:\.self) { proto in
                    Text(proto.rawValue).tag(proto as DecoderType?)
                }
            }

            TextField("Address:", value: $train.addressValue,
                      format: .number)
                        
            TrainIconView(trainIconManager: trainIconManager, train: train, size: .large)
            
            Spacer()
        }
    }
}

extension Train {
    
    var addressDecoderType: DecoderType? {
        get {
            return address.decoderType
        }
        set {
            address = .init(address.address, newValue)
        }
    }
    
    var addressValue: Int {
        get {
            return Int(address.address)
        }
        set {
            address = .init(UInt32(newValue), addressDecoderType)
        }
    }
}

struct TrainEditView_Previews: PreviewProvider {
    
    static let layout = LayoutACreator().newLayout()
    
    static var previews: some View {
        TrainEditView(layout: layout, train: layout.trains[0], trainIconManager: TrainIconManager(layout: layout))
    }
}
