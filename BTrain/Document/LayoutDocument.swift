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

/// This is the root model class that holds everything needed to manage a  layout.
/// It also handles loading and saving of the layout model to disk.
final class LayoutDocument: ObservableObject {
        
    /// The layout model
    @Published var layout: Layout

    /// The layout coordinator which manages the layout in real-time during train operations
    @Published var layoutController: LayoutController

    /// The visual representation of the layout
    @Published var switchboard: SwitchBoard

    /// Interface to communicate with the Digital Controller
    let interface: CommandInterface

    /// Class that is used to diagnostic the layout and report any error
    let layoutDiagnostics: LayoutDiagnostic
        
    /// The Digital Controller simulator when working offline
    let simulator: MarklinCommandSimulator

    /// The centralized class that manages all train icon-related functions
    let trainIconManager: TrainIconManager
    
    /// If non-nil, the instance of the class that is measuring the speed of a train
    var measurement: TrainSpeedMeasurement?

    /// True if the layout is connected to the Digital Controller, false otherwise
    @Published var connected = false

    /// Used to trigger the layout diagnostic from the UX
    @Published var triggerLayoutDiagnostic = false
    
    /// Used to trigger the switchboard setting dialog from the UX
    @Published var triggerSwitchboardSettings = false

    /// Property used to confirm the download of the locomotives command
    @Published var discoverLocomotiveConfirmation = false

    /// Property used to switch to a specific view type
    @AppStorage("selectedView") var selectedView: ViewType = .overview

    /// Property used to toggle showing debug-only controls
    @AppStorage(SettingsKeys.debugMode) var showDebugModeControls = false
        
    /// Class handling tasks that must run when the connection to the Digital Controller is established
    @Published var onConnectTasks: LayoutOnConnectTasks

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
    }
    
    func apply(_ other: Layout) {
        layout.apply(other: other)
        switchboard.fitSize()
    }
}
