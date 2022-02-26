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

struct TrainControlStateView: View {
    
    @ObservedObject var train: Train
    
    var stateString: String {
        switch train.state {
        case .running:
            return "Running"
        case .braking:
            return "Braking"
        case .stopping:
            return "Stopping"
        case .stopped:
            return "-"
        }
    }
    
    var statusInformation: String {
        if train.automaticFinishingScheduling {
            return "\(stateString) - finishing"
        }
        
        if train.automaticScheduling {
            return "\(stateString) - automatic"
        }
        
        return stateString
    }
    
    var body: some View {
        HStack {
            Text("Status:")
                .font(Font.body.weight(.medium))
            Text("\(train.runtimeInfo ?? statusInformation)")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

}
