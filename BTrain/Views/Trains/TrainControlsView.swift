// Copyright 2021 Jean Bovet
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

struct TrainControlsView: View {
    
    @ObservedObject var document: LayoutDocument

    @ObservedObject var train: Train

    @State private var speed = 0.0
    
    @State private var trainForward = true

    @State private var errorStatus: String?

    func trainDirectionToggle() {
        let command: Command
        if trainForward {
            command = .forward(address: train.address)
        } else {
            command = .backward(address: train.address)
        }
        document.interface!.execute(command: command)
        
        do {
            try document.layout.toggleTrainDirection(train)
            errorStatus = nil
        } catch {
            errorStatus = error.localizedDescription
        }        
    }
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    trainForward.toggle()
                    trainDirectionToggle()
                } label: {
                    if trainForward {
                        Image(systemName: "arrowtriangle.right.fill")
                    } else {
                        Image(systemName: "arrowtriangle.left.fill")
                    }
                }.buttonStyle(.borderless)
                
                Slider(
                    value: $speed,
                    in: 0...100
                ) {
                } onEditingChanged: { editing in
                    train.speed = UInt16(speed)
                }
                
                Text("\(Int(speed)) km/h")
            }.disabled(!document.connected)
            if let errorStatus = errorStatus {
                Text(errorStatus)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.red)
            }
        }.onAppear {
            speed = train.speedAsDouble
            if let direction = try? document.layout.direction(ofTrain: train) {
                trainForward = direction == .next
            }
        }
    }
}

extension Train {
    
    // Necessary because SwiftUI Slider requires a Double
    // while speed is UInt16.
    var speedAsDouble: Double {
        get {
            return Double(self.speed)
        }
        set {
            self.speed = UInt16(newValue)
        }
    }
    
}

struct TrainControlsView_Previews: PreviewProvider {
    
    static let doc: LayoutDocument = {
        let layout = LayoutACreator().newLayout()
        return LayoutDocument(layout: layout)
    }()

    static var previews: some View {
        TrainControlsView(document: doc, train: doc.layout.mutableTrains[0])
    }
}
