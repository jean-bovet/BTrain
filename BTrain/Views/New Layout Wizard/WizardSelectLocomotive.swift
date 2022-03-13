//
//  WizardSelectLocomotive.swift
//  BTrain
//
//  Created by Jean Bovet on 3/13/22.
//

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
