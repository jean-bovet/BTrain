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
import UniformTypeIdentifiers

// This is the class defining the document for a single layout document.
// It is used across all the views of the application and contains
// the data model shared by these views.
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
    
    enum ViewType: String, Identifiable, CaseIterable {
        var id : String { rawValue }

        case switchboard = "Switchboard"
        case routes = "Routes"
        case locomotives = "Locomotives"
        case blocks = "Blocks"
        case turnouts = "Turnouts"
        case feedback = "Feedback"
    }
        
    // Interface used to communicate with the real layout
    @Published var interface: ProxyCommandInterface
    
    // The layout model
    @Published private(set) var layout: Layout

    var layoutDiagnostics: LayoutDiagnostic

    @Published var coordinator: LayoutCoordinator

    @Published var switchboard: SwitchBoard
    
    // Used to perform the menu command "Diagnostics"
    @Published var diagnostics = false
    
    @Published var repairLayoutTrigger = false

    @Published var discoverLocomotiveConfirmation = false
    
    @Published var importPredefinedLayout = false

    // Used to perform the menu command "Switch View"
    @AppStorage("selectedView") var selectedView: ViewType = .switchboard

    // Toggle to display debug-only controls
    @AppStorage("debugMode") var debugMode = false
        
    // This property is used to keep track of the connection status.
    // True if connected to the Digital Controller interface,
    // false otherwise.
    @Published var connected = false

    // This property is used to keep track of the progress when activating the turnouts
    // when connecting to the Digital Controller
    @Published var activateTurnountPercentage: Double? = nil

    // The simulator that can be used in place of a real Digital Controller
    var simulator: MarklinCommandSimulator
        
    init(layout: Layout) {
        self.layout = layout
        self.layoutDiagnostics = LayoutDiagnostic(layout: layout)
        self.simulator = MarklinCommandSimulator(layout: layout)
        self.switchboard = SwitchBoardFactory.generateSwitchboard(layout: layout)

        let interface = ProxyCommandInterface()
        self.interface = interface
        self.coordinator = LayoutCoordinator(layout: layout, interface: interface)
        layout.executor = LayoutCommandExecutor(layout: layout, interface: interface)
    }
}

// MARK: ReferenceFileDocument

extension LayoutDocument: ReferenceFileDocument {
    
    static var readableContentTypes: [UTType] { [.json] }
    
    convenience init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let layout = try LayoutDocument.layout(contentType: configuration.contentType, data: data)
        self.init(layout: layout)
    }
    
    func fileWrapper(snapshot: Data, configuration: WriteConfiguration) throws -> FileWrapper {
        switch configuration.contentType {
        case .json:
            return .init(regularFileWithContents: snapshot)
        default:
            throw CocoaError(.fileWriteUnsupportedScheme)
        }
    }

    static func layout(contentType: UTType, data: Data) throws -> Layout {
        guard contentType == .json else {
            throw CocoaError(.fileReadUnknown)
        }
        let decoder = JSONDecoder()
        let layout = try decoder.decode(Layout.self, from: data)
        return layout
    }
    
    func snapshot(contentType: UTType) throws -> Data {
        let encoder = JSONEncoder()
        let data = try encoder.encode(layout)
        return data
    }

}

// MARK: Commands

extension LayoutDocument {
    
    func enable(onCompletion: @escaping () -> Void) {
        interface.execute(command: .go(), onCompletion: onCompletion)
    }
    
    func disable(onCompletion: @escaping () -> Void) {
        interface.execute(command: .stop(), onCompletion: onCompletion)
    }
    
    func start(train: Identifier<Train>, withRoute route: Identifier<Route>, toBlockId: Identifier<Block>?) throws {
        // Note: the simulator holds a reference to the layout and will automatically simulate any
        // enabled route associated with a train.
        try coordinator.start(routeID: route, trainID: train, toBlockId: toBlockId)
    }
    
    func stop(train: Train) throws {
        guard let route = train.routeId else {
            throw LayoutError.trainNotAssignedToARoute(train: train)
        }
                
        try coordinator.stop(routeID: route, trainID: train.id)
    }
    
    func connectToSimulator(completed: ((Error?) -> Void)? = nil) {
        simulator.start()
        connect(address: "localhost", port: 15731, completed: completed)
    }
    
    func connect(address: String, port: UInt16, completed: ((Error?) -> Void)? = nil) {
        let mi = MarklinInterface(server: address, port: port)
        mi.connect {
            DispatchQueue.main.async {
                self.connected = true
                self.interface.interface = mi
                self.registerForFeedbackChange()
                self.registerForSpeedChange()
                self.registerForDirectionChange()
                self.registerForTurnoutChange()
                completed?(nil)
            }
        } onError: { error in
            DispatchQueue.main.async {
                self.connected = false
                self.interface.interface = nil
                completed?(error)
            }
        } onStop: {
            DispatchQueue.main.async {
                self.connected = false
                self.interface.interface = nil
            }
        }
    }
    
    func disconnect() {
        simulator.stop()
        interface.disconnect() { }
    }
        
    func applyTurnoutStateToDigitalController(completion: @escaping CompletionBlock) {
        let turnouts = layout.turnouts
        guard !turnouts.isEmpty else {
            completion()
            return
        }
        
        activateTurnountPercentage = 0.0
        var completionCount = 0
        for t in turnouts {
            layout.executor?.sendTurnoutState(turnout: t) {
                completionCount += 1
                self.activateTurnountPercentage = Double(completionCount) / Double(turnouts.count)
                if completionCount == turnouts.count {
                    self.activateTurnountPercentage = nil
                    completion()
                }
            }
        }
    }
    
    func registerForFeedbackChange() {
        interface.register(forFeedbackChange: { deviceID, contactID, value in
            if let feedback = self.coordinator.layout.feedbacks.find(deviceID: deviceID, contactID: contactID) {
                feedback.detected = value == 1
            }
        })
    }
                
    func registerForSpeedChange() {
        interface.register(forSpeedChange: { address, speed in
            DispatchQueue.main.async {
                if let train = self.coordinator.layout.trains.find(address: address.address) {
                    train.speed = speed
                }
            }
        })
    }
    
    func registerForDirectionChange() {
        interface.register(forDirectionChange: { address, direction in
            DispatchQueue.main.async {
                if let train = self.coordinator.layout.trains.find(address: address) {
                    switch(direction) {
                    case .forward:
                        if train.directionForward == false {
                            train.directionForward = true
                            try? self.layout.toggleTrainDirectionInBlock(train)
                        }
                    case .backward:
                        if train.directionForward {
                            train.directionForward = false
                            try? self.layout.toggleTrainDirectionInBlock(train)
                        }
                    case .unknown:
                        BTLogger.error("Unknown direction \(direction) for \(address.toHex())")
                    }
                } else {
                    BTLogger.error("Unknown address \(address.toHex()) for change in direction event")
                }
            }
        })
    }
    
    func registerForTurnoutChange() {
        interface.register(forTurnoutChange: { address, state, power in
            if let turnout = self.coordinator.layout.turnouts.find(address: address) {
                BTLogger.debug("Turnout \(turnout.name) changed to \(state)")
                turnout.stateValue = state
                self.layout.didChange()
            } else {
                BTLogger.error("Unknown turnout for address \(address.actualAddress.toHex())")
            }
        })
    }
    
}
