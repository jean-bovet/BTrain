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

/// Discover locomotives from the Digital Controller and populate the layout with them.
final class LocomotiveDiscovery {
    let interface: CommandInterface
    let layout: Layout
    let locomotiveIconManager: LocomotiveIconManager

    private var callbackUUID: UUID?

    init(interface: CommandInterface, layout: Layout, locomotiveIconManager: LocomotiveIconManager) {
        self.interface = interface
        self.layout = layout
        self.locomotiveIconManager = locomotiveIconManager
    }

    deinit {
        unregisterCallback()
    }

    func discover(merge: Bool, completion: CompletionBlock? = nil) {
        unregisterCallback()

        callbackUUID = interface.callbacks.register(forLocomotivesQuery: { [weak self] locomotives in
            DispatchQueue.main.async {
                self?.unregisterCallback()
                self?.process(locomotives: locomotives, merge: merge)
                completion?()
            }
        })

        interface.execute(command: .locomotives(), completion: nil)
    }

    private func unregisterCallback() {
        if let callbackUUID = callbackUUID {
            interface.callbacks.unregister(uuid: callbackUUID)
        }
    }

    private func process(locomotives: [CommandLocomotive], merge: Bool) {
        var newLocs = [Locomotive]()
        for cmdLoc in locomotives {
            if let locUID = cmdLoc.uid, let loc = layout.locomotives[Identifier<Locomotive>(uuid: String(locUID))], merge {
                mergeLocomotive(cmdLoc, with: loc)
            } else if let locAddress = cmdLoc.address, let loc = layout.locomotives.elements.find(address: locAddress, decoder: cmdLoc.decoderType), merge {
                mergeLocomotive(cmdLoc, with: loc)
            } else {
                let loc: Locomotive
                if let locUID = cmdLoc.uid {
                    loc = Locomotive(uuid: String(locUID))
                } else {
                    loc = Locomotive()
                }
                mergeLocomotive(cmdLoc, with: loc)
                newLocs.append(loc)
            }
        }

        if merge {
            layout.locomotives.elements.append(contentsOf: newLocs)
        } else {
            layout.removeAllLocomotives()
            layout.locomotives.elements = newLocs
        }
    }

    private func mergeLocomotive(_ locomotive: CommandLocomotive, with loc: Locomotive) {
        if let name = locomotive.name {
            loc.name = name
        }
        if let address = locomotive.address {
            loc.address = address
        }
        if let maxSpeed = locomotive.maxSpeed {
            loc.speed.maxSpeed = SpeedKph(maxSpeed)
        }
        loc.decoder = locomotive.decoderType ?? .MFX
        if let icon = locomotive.icon {
            try! locomotiveIconManager.setIcon(icon, locId: loc.id)
        }

        loc.functions.definitions = locomotive.functions
    }
}
