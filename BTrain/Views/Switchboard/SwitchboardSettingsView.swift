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

struct SwitchboardSettingsView: View {
    
    let document: LayoutDocument

    @AppStorage("showBlockName") var showBlockName: Bool = false
    @AppStorage("showStationName") var showStationName: Bool = false
    @AppStorage("showTurnoutName") var showTurnoutName: Bool = false
    @AppStorage("showTrainIcon") var showTrainIcon: Bool = false
    @AppStorage("showSimulator") var showSimulator: Bool = false

    var body: some View {
        HStack {
            Toggle("Block Name", isOn: $showBlockName)
            Toggle("Station Name", isOn: $showStationName)
                .disabled(showBlockName)
            Toggle("Turnout Name", isOn: $showTurnoutName)
            Toggle("Train Icon", isOn: $showTrainIcon)
            if document.simulator.enabled {
                Toggle("Simulator", isOn: $showSimulator)
            }
            
            Spacer()
            
            Button("􀝯") {
                document.switchboard.state.zoomToFit = true
            }
            Button("􀊮") {
                document.switchboard.state.zoomToFit = false
            }
        }.padding()
    }
}

struct SwitchboardSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SwitchboardSettingsView(document: LayoutDocument(layout: Layout()))
    }
}
