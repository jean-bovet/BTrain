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

    @Binding var trainRuntimeError: String?

    @State private var showingAlert = false

    let size = 10.0

    var stateString: String {
        switch train.state {
        case .running:
            return "Running"
        case .braking:
            return "Braking"
        case .stopping:
            return "Stopping"
        case .stopped:
            return "Stopped"
        }
    }

    var statusInformation: String {
        switch train.scheduling {
        case .unmanaged:
            return stateString
        case .managed:
            return "\(stateString) - automatic"
        case .stopManaged:
            return "\(stateString) - stopping"
        case .stopImmediatelyManaged:
            return "\(stateString) - stop immediately"
        case .finishManaged:
            return "\(stateString) - finishing"
        }
    }

    var stateColor: Color {
        switch train.state {
        case .running:
            return .green
        case .braking:
            return .yellow
        case .stopping:
            return .orange
        case .stopped:
            return .red
        }
    }

    var body: some View {
        HStack {
            if let runtimeInfo = trainRuntimeError {
                Button("􀇾") {
                    showingAlert.toggle()
                }
                .foregroundColor(.red)
                .buttonStyle(.borderless)
                .help(runtimeInfo)
                .alert(runtimeInfo, isPresented: $showingAlert) {
                    Button("OK", role: .cancel) {}.keyboardShortcut(.defaultAction)

                    Button("Clear") {
                        trainRuntimeError = nil
                    }
                }
            }
            Circle()
                .frame(width: size, height: size)
                .foregroundColor(stateColor)
                .help(statusInformation)
        }
    }
}

struct TrainControlStateView_Previews: PreviewProvider {
    static func train(with state: Train.State) -> Train {
        let t = Train()
        t.state = state
        return t
    }

    static var previews: some View {
        Group {
            TrainControlStateView(train: train(with: .stopped), trainRuntimeError: .constant(nil))
        }
        Group {
            TrainControlStateView(train: train(with: .stopped), trainRuntimeError: .constant("There was an error"))
        }
        Group {
            TrainControlStateView(train: train(with: .running), trainRuntimeError: .constant(nil))
        }
        Group {
            TrainControlStateView(train: train(with: .braking), trainRuntimeError: .constant(nil))
        }
        Group {
            TrainControlStateView(train: train(with: .stopping), trainRuntimeError: .constant(nil))
        }
    }
}
