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

import Foundation
import SwiftUI

// This class defines a layout document which is persisted to disk.
//                                          ┌──────────────────┐
//          ┌────────────────────────────┬──│  LayoutDocument  │───┬────────────────────────────┐
//          │                            │  └──────────────────┘   │                            │
//          │                            │                         │                            │
//          ▼                            ▼                         ▼                            ▼
//┌──────────────────┐         ┌──────────────────┐           ┌─────────┐             ┌──────────────────┐
//│ CommandInterface │◀────────│LayoutCoordinator │──────────▶│ Layout  │◀────────────│   Switchboard    │
//└──────────────────┘         └──────────────────┘           └─────────┘             └──────────────────┘
//

final class CommandTrigger: ObservableObject {
}

final class LayoutDocument: ObservableObject {
    
    // This property is used to keep track of the connection status.
    // True if connected to the Digital Controller interface,
    // false otherwise.
    @Published var connected = false

    // Interface to communicate with the Digital Controller
    @Published var interface: ProxyCommandInterface
    
    // The layout model
    @Published var layout: Layout

    // A class that is used to diagnostic the layout and report any error
    let layoutDiagnostics: LayoutDiagnostic

    // The layout coordinator which updates the layout in real-time during train operations
    @Published var layoutController: LayoutController

    // The visual representation of the layout
    @Published var switchboard: SwitchBoard
        
    // The simulator that can be used in place of a real Digital Controller
    let simulator: MarklinCommandSimulator

    // The centralized class that manages all train icon-related functions
    let trainIconManager: TrainIconManager

    // The class that measures the true speed for each train
    let trainSpeedMeasurement: TrainSpeedMeasurement
    
    // Property used to perform the layout diagnostic command
    @Published var triggerLayoutDiagnostic = false

    // Property used to perform the layout repair command
    @Published var triggerRepairLayout = false
    
    // Property used to perform the import of a predefined layout command
    @Published var triggerImportPredefinedLayout = false

    // Property used to confirm the download of the locomotives command
    @Published var discoverLocomotiveConfirmation = false

    // Property used to switch to a specific view type
    @AppStorage("selectedView") var selectedView: ViewType = .overview

    // Property used to toggle showing debug-only controls
    @AppStorage("debugMode") var showDebugModeControls = false
            
    @Published var onConnectTasks: LayoutOnConnectTasks
    
    init(layout: Layout) {
        self.layout = layout
        
        let interface = ProxyCommandInterface()
        let simulator = MarklinCommandSimulator(layout: layout, interface: interface)
        let switchboard = SwitchBoardFactory.generateSwitchboard(layout: layout, simulator: simulator)
        let layoutController = LayoutController(layout: layout, switchboard: switchboard, interface: interface)

        layout.executor = LayoutCommandExecutor(layout: layout, interface: interface)

        self.interface = interface
        self.simulator = simulator
        self.layoutDiagnostics = LayoutDiagnostic(layout: layout)
        self.trainIconManager = TrainIconManager(layout: layout)
        self.trainSpeedMeasurement = TrainSpeedMeasurement(layout: layout, interface: interface)
        self.switchboard = switchboard
        self.layoutController = layoutController
                
        self.onConnectTasks = LayoutOnConnectTasks(layout: layout, layoutController: layoutController, interface: interface)
    }
    
    func apply(_ other: Layout) {
        layout.apply(other: other)
        switchboard.fitSize()
    }
}
