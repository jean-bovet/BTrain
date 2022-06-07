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
final class LayoutDocument: ObservableObject {
    
    // This property is used to keep track of the connection status.
    // True if connected to the Digital Controller interface,
    // false otherwise.
    @Published var connected = false

    // Interface to communicate with the Digital Controller
    let interface: CommandInterface
    
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
    
    // If non-nil, the instance of the class that is measuring the speed of a train
    var measurement: TrainSpeedMeasurement?

    // Property used to perform the layout diagnostic command
    @Published var triggerLayoutDiagnostic = false
    @Published var triggerSwitchboardSettings = false

    // Property used to confirm the download of the locomotives command
    @Published var discoverLocomotiveConfirmation = false

    // Property used to switch to a specific view type
    @AppStorage("selectedView") var selectedView: ViewType = .overview

    // Property used to toggle showing debug-only controls
    @AppStorage(SettingsKeys.debugMode) var showDebugModeControls = false
            
    @Published var onConnectTasks: LayoutOnConnectTasks
    @Published var messages = [MarklinCANMessage]()
    
    init(layout: Layout, interface: CommandInterface = MarklinInterface()) {
        let simulator = MarklinCommandSimulator(layout: layout, interface: interface)
        
        let trainIconManager = TrainIconManager()
        
        let context = ShapeContext(simulator: simulator, trainIconManager: trainIconManager)
        let shapeProvider = ShapeProvider(layout: layout, context: context)
        let switchboard = SwitchBoard(layout: layout, provider: shapeProvider, context: context)
        
        let layoutController = LayoutController(layout: layout, switchboard: switchboard, interface: interface)
        
        self.layout = layout
        self.interface = interface
        self.simulator = simulator
        self.layoutDiagnostics = LayoutDiagnostic(layout: layout)
        self.trainIconManager = trainIconManager
        self.switchboard = switchboard
        self.layoutController = layoutController
                
        self.onConnectTasks = LayoutOnConnectTasks(layout: layout, layoutController: layoutController, interface: interface)
        
        switchboard.provider.layoutController = layoutController
        switchboard.update()

        layoutDiagnostics.automaticCheck()
        
        if let marklin = interface as? MarklinInterface {
            marklin.register { [weak self] canMessage in
                self?.messages.append(canMessage)
            }
        }
    }
    
    func apply(_ other: Layout) {
        layout.apply(other: other)
        switchboard.fitSize()
    }
}
