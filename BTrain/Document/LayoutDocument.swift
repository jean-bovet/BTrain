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

    /// The locomotive icon manager
    let locomotiveIconManager: LocomotiveIconManager

    /// The locomotive discovery class
    let locomotiveDiscovery: LocomotiveDiscovery

    /// The catalog of locomotive functions
    let locomotiveFunctionsCatalog: LocomotiveFunctionsCatalog

    /// True if the layout is connected to the Digital Controller, false otherwise
    @Published var connected = false {
        didSet {
            listenToPowerEvents()
        }
    }

    /// Set of trains that have been pinned by the user
    @Published var pinnedTrainIds = Set<Identifier<Train>>()

    /// True if the layout has power enabled, false otherwise. It is only valid
    /// if the ``connected`` attribute is true.
    @Published var power = false

    /// Used to trigger the layout diagnostic from the UX
    @Published var triggerLayoutDiagnostic = false

    /// Used to show or hide the switchboard view settings
    @Published var showSwitchboardViewSettings = false

    /// Show the specific sheet type
    @Published var displaySheetType = DisplaySheetType.routeScripts {
        didSet {
            displaySheet.toggle()
        }
    }

    /// Toggle showing the sheet when the sheet type changes
    @Published var displaySheet = false

    /// Property used to toggle showing debug-only controls
    @AppStorage(SettingsKeys.debugMode) var showDebugModeControls = false

    /// Class handling tasks that must run when the connection to the Digital Controller is established
    @Published var onConnectTasks: LayoutOnConnectTasks

    /// True if at least one train can be started
    @Published var trainsThatCanBeStarted = false

    /// True if at least one train can be stopped
    @Published var trainsThatCanBeStopped = false

    /// True if at least one train can be finished
    @Published var trainsThatCanBeFinished = false

    /// True if the document is a new document. This is used to trigger
    /// the new document wizard to help pre-populate the switchboard
    /// with a predefined layout and locomotives.
    @Published var newDocument = false

    /// If non-nil, the instance of the class that is measuring the speed of a train
    var measurement: LocomotiveSpeedMeasurement?

    private let trainsStateObserver: LayoutTrainsStateObserver
    private let trainsSchedulingObserver: LayoutTrainsSchedulingObserver
    private var stateChangeUUID: UUID?

    init(layout: Layout, interface: CommandInterface = MarklinInterface()) {
        let simulator = MarklinCommandSimulator(layout: layout, interface: interface)

        let locomotiveIconManager = LocomotiveIconManager()

        let context = ShapeContext(simulator: simulator, locomotiveIconManager: locomotiveIconManager)
        let shapeProvider = ShapeProvider(layout: layout, context: context)
        let switchboard = SwitchBoard(layout: layout, provider: shapeProvider, context: context)

        let catalog = LocomotiveFunctionsCatalog(interface: interface)
        let layoutController = LayoutController(layout: layout, switchboard: switchboard, interface: interface, functionCatalog: catalog)

        self.layout = layout
        self.interface = interface
        self.simulator = simulator
        layoutDiagnostics = LayoutDiagnostic(layout: layout)
        self.locomotiveIconManager = locomotiveIconManager
        self.locomotiveFunctionsCatalog = catalog

        self.switchboard = switchboard
        self.layoutController = layoutController

        let discovery = LocomotiveDiscovery(interface: interface, layout: layout, locomotiveIconManager: locomotiveIconManager)
        onConnectTasks = LayoutOnConnectTasks(layout: layout, layoutController: layoutController, interface: interface, locFuncCatalog: locomotiveFunctionsCatalog, locomotiveDiscovery: discovery)

        switchboard.provider.layoutController = layoutController
        switchboard.update()

        trainsStateObserver = LayoutTrainsStateObserver(layout: layout)
        trainsSchedulingObserver = LayoutTrainsSchedulingObserver(layout: layout)

        locomotiveDiscovery = discovery

        listenToTrainsStateChange(layout: layout)
    }

    func apply(_ other: Layout) {
        layout.apply(other: other)
        switchboard.fitSize()
    }

    /// Listen to change in the train state and scheduling attributes
    /// - Parameter layout: the layout
    private func listenToTrainsStateChange(layout _: Layout) {
        trainsStateObserver.registerForChange { [weak self] _ in
            self?.trainStateChanged()
        }
        trainsSchedulingObserver.registerForChange { [weak self] _ in
            self?.trainStateChanged()
        }
    }

    /// Re-compute the states that depend from a train internal state
    private func trainStateChanged() {
        trainsThatCanBeStarted = layout.trainsThatCanBeStarted().count > 0
        trainsThatCanBeStopped = layout.trainsThatCanBeStopped().count > 0
        trainsThatCanBeFinished = layout.trainsThatCanBeFinished().count > 0
    }

    /// Listen to power event from the Digital Controller (power on, power off)
    private func listenToPowerEvents() {
        if connected {
            stateChangeUUID = interface.callbacks.stateChanges.register { [weak self] enabled in
                self?.power = enabled
            }
        } else if let stateChangeUUID = stateChangeUUID {
            interface.callbacks.stateChanges.unregister(stateChangeUUID)
            self.stateChangeUUID = nil
        }
    }
}

extension LayoutDocument {
    /// The various type of sheets that can be displayed
    enum DisplaySheetType: String, CaseIterable {
        case layoutScripts = "Layout Scripts"
        case routeScripts = "Route Scripts"
        case routes = "Routes"
        case trains = "Trains"
        case locomotives = "Locomotives"
        case stations = "Stations"
        case blocks = "Blocks"
        case turnouts = "Turnouts"
        case feedbacks = "Feedbacks"
        case cs3 = "Central Station 3 Debugger"

        var label: String {
            switch self {
            case .layoutScripts:
                return "Scripts"
            case .routeScripts:
                return "Routes"
            case .routes:
                return "Steps"
            case .trains:
                return "Trains"
            case .locomotives:
                return "Locomotives"
            case .stations:
                return "Stations"
            case .blocks:
                return "Blocks"
            case .turnouts:
                return "Turnouts"
            case .feedbacks:
                return "Feedbacks"
            case .cs3:
                return "Central Station 3 Debugger"
            }
        }

        var shortcut: KeyEquivalent? {
            switch self {
            case .layoutScripts:
                return "1"
            case .routeScripts:
                return "2"
            case .routes:
                return nil
            case .trains:
                return "3"
            case .locomotives:
                return "4"
            case .stations:
                return "5"
            case .blocks:
                return "6"
            case .turnouts:
                return "7"
            case .feedbacks:
                return "8"
            case .cs3:
                return nil
            }
        }

        var debugOnly: Bool {
            self == .routes || self == .cs3
        }
    }
}
