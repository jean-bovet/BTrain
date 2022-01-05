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

struct OverviewView: View {
    
    @ObservedObject var document: LayoutDocument
                
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                TrainListView(layout: document.layout, document: document)
                if document.simulator.started {
                    SimulatorView(simulator: document.simulator)
                }
            }
            .frame(width: 500)

            if let switchboard = document.switchboard, let layout = document.layout, let coordinator = document.coordinator {
                OverviewSwitchboardView(layout: layout, coordinator: coordinator, document: document, switchboard: switchboard, state: switchboard.state)
            }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    
    static let doc = LayoutDocument(layout: LayoutCCreator().newLayout())

    static var previews: some View {
        OverviewView(document: doc)
    }
}
