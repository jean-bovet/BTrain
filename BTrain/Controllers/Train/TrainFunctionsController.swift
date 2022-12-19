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

final class TrainFunctionsController {
    let catalog: LocomotiveFunctionsCatalog?
    let interface: CommandInterface

    internal init(catalog: LocomotiveFunctionsCatalog?, interface: CommandInterface) {
        self.catalog = catalog
        self.interface = interface
    }

    func execute(functions: RouteItemFunctions, train: Train) {
        guard let functions = functions.functions else {
            return
        }

        guard let locomotive = train.locomotive else {
            return
        }

        BTLogger.debug("Execute \(functions.count) functions for \(train)")

        for f in functions {
            let type = f.type

            guard let def = locomotive.functions.definitions.first(where: { $0.type == type }) else {
                BTLogger.warning("Function \(type) not found in locomotive \(locomotive)")
                continue
            }

            if let name = catalog?.name(for: type) {
                BTLogger.debug("Execute function \(name) of type \(type) with \(locomotive.name)")
            } else {
                BTLogger.debug("Execute function of type \(type) with \(locomotive.name)")
            }

            execute(locomotive: locomotive, function: def, trigger: f.trigger, duration: f.duration)
        }
    }

    func execute(locomotive: Locomotive, function: CommandLocomotiveFunction, trigger: RouteItemFunction.Trigger, duration: TimeInterval) {
        switch trigger {
        case .enable, .disable:
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.executeSingle(locomotive: locomotive, function: function, trigger: trigger)
            }

        case .pulse:
            executePulse(locomotive: locomotive, function: function, duration: duration)
        }
    }

    private func executeSingle(locomotive: Locomotive, function: CommandLocomotiveFunction, trigger: RouteItemFunction.Trigger) {
        let initialValue = trigger == .disable ? 0 : 1
        interface.execute(command: .function(address: locomotive.address, decoderType: locomotive.decoder, index: function.nr, value: UInt8(initialValue)), completion: nil)

        if function.toggle {
            // The Digital Controller (at least the CS3) does not toggle it back
            // automatically, so we have to do it.
            let finalValue = UInt8(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self.interface.execute(command: .function(address: locomotive.address, decoderType: locomotive.decoder, index: function.nr, value: finalValue), completion: nil)
            }
        }
    }

    private func executePulse(locomotive: Locomotive, function: CommandLocomotiveFunction, duration: TimeInterval) {
        let initialValue = UInt8(1)
        interface.execute(command: .function(address: locomotive.address, decoderType: locomotive.decoder, index: function.nr, value: initialValue), completion: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            let finalValue = UInt8(0)
            self.interface.execute(command: .function(address: locomotive.address, decoderType: locomotive.decoder, index: function.nr, value: finalValue), completion: nil)
        }
    }
}
