//
//  TrainEditListView.swift
//  BTrain
//
//  Created by Jean Bovet on 11/2/21.
//

import SwiftUI

struct TrainEditListView: View {
    @EnvironmentObject var app: AppModel

    @Binding var trains: [BTTrain]

    var body: some View {
        List {
            ForEach($trains) { train in
                GroupBox {
                    TrainEditView(train: train)
                }
            }
        }
    }
}

struct LocoListView_Previews: PreviewProvider {
    static let model = AppModel()
        .setLayout(BTLayoutV8Creator().newLayout())

    static var previews: some View {
        TrainEditListView(trains: .constant(model.layout.trains))
            .environmentObject(model)
    }
}
