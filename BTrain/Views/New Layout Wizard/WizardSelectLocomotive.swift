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

struct WizardSelectLocomotive: View {
    
    let document: LayoutDocument
    @Binding var selectedTrains: Set<Identifier<Train>>

    @Environment(\.colorScheme) var colorScheme

    let previewSize = CGSize(width: 300, height: 200)

    var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(NSColor.windowBackgroundColor)
        } else {
            return .white
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Select one ore more Locomotive:")
                .font(.largeTitle)
                .padding()
            ScrollView(.horizontal) {
                LazyHStack {
                    ForEach(document.layout.trains, id:\.self) { train in
                        ZStack {
                            Rectangle()
                                .frame(width: previewSize.width, height: previewSize.height)
                                .cornerRadius(5)
                                .foregroundColor(backgroundColor)
                                .shadow(radius: 5)
                            
                            VStack {
                                TrainIconView(trainIconManager: document.trainIconManager, train: train, size: .large, hideIfNotDefined: true)
                                Text(train.name)
                            }
                            .frame(width: previewSize.width, height: previewSize.height)

                            Rectangle()
                                .frame(width: previewSize.width, height: previewSize.height)
                                .background(.clear)
                                .foregroundColor(.clear)
                                .border(.tint, width: 3)
                                .hidden(!selectedTrains.contains(train.id))
                        }
                        .onTapGesture {
                            if selectedTrains.contains(train.id) {
                                selectedTrains.remove(train.id)
                            } else {
                                selectedTrains.insert(train.id)
                            }
                        }
                        .padding()
                    }
                }
            }
        }.onAppear {
            if let train = document.layout.trains.first {
                selectedTrains.insert(train.id)
            }
        }
    }
    
}

struct WizardSelectLocomotive_Previews: PreviewProvider {
    
    static let helper: PredefinedLayoutHelper = {
       let h = PredefinedLayoutHelper()
        try? h.load()
        return h
    }()
    
    static var previews: some View {
        WizardSelectLocomotive(document: helper.predefinedDocument!, selectedTrains: .constant([]))
    }
}
