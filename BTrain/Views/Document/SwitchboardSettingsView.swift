//
//  SwitchboardSettingsView.swift
//  BTrain
//
//  Created by Jean Bovet on 3/21/22.
//

import SwiftUI

struct SwitchboardSettingsView: View {
    
    @Environment(\.presentationMode) var presentationMode

    @AppStorage("showBlockName") var showBlockName: Bool = false
    @AppStorage("showStationName") var showStationName: Bool = false
    @AppStorage("showTurnoutName") var showTurnoutName: Bool = false
    @AppStorage("showTrainIcon") var showTrainIcon: Bool = false
    @AppStorage("showSimulator") var showSimulator: Bool = false

    var body: some View {
        VStack {
            Form {
                Toggle("Block Name", isOn: $showBlockName)
                Toggle("Station Name", isOn: $showStationName)
                Toggle("Turnout Name", isOn: $showTurnoutName)
                Toggle("Train Icon", isOn: $showTrainIcon)
                Toggle("Simulator", isOn: $showSimulator)
            }.padding()
            Divider()
            HStack {
                Button("OK") {
                    presentationMode.wrappedValue.dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct SwitchboardSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SwitchboardSettingsView()
    }
}
