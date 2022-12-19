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

final class LayoutOnConnectTasks: ObservableObject {
    let layout: Layout
    let layoutController: LayoutController
    let interface: CommandInterface
    let catalog: LocomotiveFunctionsCatalog
    let discovery: LocomotiveDiscovery

    /// Property used to keep track of the progress
    @Published var connectionCompletionPercentage: Double? = nil
    @Published var connectionCompletionLabel: String? = nil

    var cancel = false

    init(layout: Layout, layoutController: LayoutController, interface: CommandInterface, locFuncCatalog: LocomotiveFunctionsCatalog, locomotiveDiscovery: LocomotiveDiscovery) {
        self.layout = layout
        self.layoutController = layoutController
        self.interface = interface
        self.catalog = locFuncCatalog
        self.discovery = locomotiveDiscovery
    }

    func performOnConnectTasks(simulator: Bool, activateTurnouts: Bool, completion: @escaping CompletionBlock) {
        cancel = false
        notifyProgress(label: "Fetching Locomotives", activateTurnouts: activateTurnouts, step: 0)
        fetchLocomotives {
            self.notifyProgress(label: "Querying Locomotives", activateTurnouts: activateTurnouts, step: 1)
            self.queryLocomotivesDirection {
                if activateTurnouts {
                    self.notifyProgress(label: "Activate Turnouts", activateTurnouts: activateTurnouts, step: 2)
                    self.layoutController.go {
                        self.applyTurnoutStateToDigitalController {
                            completion()
                        }
                    }
                } else {
                    self.notifyProgress(label: "Done", activateTurnouts: activateTurnouts, step: 2)
                    if !simulator {
                        // With the real digital controller, always start in stop mode by security
                        self.layoutController.stop {
                            completion()
                        }
                    } else {
                        completion()
                    }
                }
            }
        }
    }

    private func notifyProgress(label: String, activateTurnouts: Bool, step: Int) {
        let progressPercentageStep = 1.0 / (activateTurnouts ? 3 : 2)
        connectionCompletionPercentage = Double(step) * progressPercentageStep
        connectionCompletionLabel = label
    }

    private func fetchLocomotives(completion: @escaping CompletionBlock) {
        catalog.globalAttributesChanged()

        discovery.discover(merge: true) {
            completion()
        }
    }

    private func queryLocomotivesDirection(completion: @escaping CompletionBlock) {
        let locomotives = layout.locomotives.elements.filter(\.enabled)
        guard !locomotives.isEmpty else {
            completion()
            return
        }

        var completionCount = 0
        for loc in locomotives {
            let command = Command.queryDirection(address: loc.address, decoderType: loc.decoder, descriptor: nil)
            interface.execute(command: command) {
                DispatchQueue.main.async {
                    completionCount += 1
                    if completionCount == locomotives.count {
                        completion()
                    }
                }
            }
        }
    }

    private func applyTurnoutStateToDigitalController(completion: @escaping CompletionBlock) {
        let turnouts = layout.turnouts.elements
        guard !turnouts.isEmpty else {
            completion()
            return
        }

        let delta = 1.0 - (connectionCompletionPercentage ?? 0)
        var activateTurnoutPercentage = 0.0
        var completionCount = 0
        for t in turnouts {
            layoutController.sendTurnoutState(turnout: t) { _ in
                guard self.cancel == false else {
                    return
                }
                completionCount += 1
                activateTurnoutPercentage = Double(completionCount) / Double(turnouts.count)
                self.connectionCompletionPercentage = 1.0 - delta + activateTurnoutPercentage / 1.0 * delta
                if completionCount == turnouts.count {
                    self.connectionCompletionPercentage = nil
                    self.connectionCompletionLabel = nil
                    completion()
                }
            }
        }
    }
}
