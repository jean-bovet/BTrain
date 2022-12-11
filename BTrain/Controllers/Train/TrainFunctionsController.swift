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
            let enabled = f.enabled
            
            guard let def = locomotive.functions.definitions.first(where: { $0.type == type }) else {
                BTLogger.warning("Function \(type) not found in locomotive \(locomotive)")
                continue
            }
                        
            if let name = catalog?.name(for: type) {
                BTLogger.debug("Execute function \(name) of type \(type) with \(locomotive.name)")
            } else {
                BTLogger.debug("Execute function of type \(type) with \(locomotive.name)")
            }

            interface.execute(command: .function(address: locomotive.address, decoderType: locomotive.decoder, index: def.nr, value: enabled ? 1 : 0), completion: nil)
            
            if f.duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + f.duration) {
                    self.interface.execute(command: .function(address: locomotive.address, decoderType: locomotive.decoder, index: def.nr, value: enabled ? 0 : 1), completion: nil)
                }
            }
        }
    }
    

}
