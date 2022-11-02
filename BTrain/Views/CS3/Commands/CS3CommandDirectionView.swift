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

struct CS3CommandDirectionView: View {

    let doc: LayoutDocument
    let query: Bool
    @Binding var command: Command?

    @State private var selectedTrain: Identifier<Train>?
    
    var body: some View {
        TrainPicker(doc: doc, selectedTrain: $selectedTrain)
            .onChange(of: selectedTrain) { newValue in
                command = command(trainId: selectedTrain)
            }
    }
    
    private func command(trainId: Identifier<Train>?) -> Command? {
        guard let trainId = trainId else {
            return nil
        }

        guard let train = doc.layout.train(for: trainId) else {
            return nil
        }
        
        if query {
            return .queryDirection(address: train.address, decoderType: train.decoder, descriptor: nil)
        } else {
            return .direction(address: train.address, decoderType: train.decoder, direction: .forward, priority: .normal, descriptor: nil)
        }
    }

}
