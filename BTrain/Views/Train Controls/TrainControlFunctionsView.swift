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

struct TrainControlFunctionsView: View {
    
    let locomotive: Locomotive

    let interface: CommandInterface
    
    let catalog: LocomotiveFunctionsCatalog
    
    @ObservedObject var functions: LocomotiveFunctions
        
    struct FunctionAttributes {
        let function: CommandLocomotiveFunction
        let name: String
        let icon: NSImage?
    }

    var functionAttributes: [FunctionAttributes] {
        var attributes = [FunctionAttributes]()
        for (index, function) in functions.definitions.enumerated() {
            let icon = catalog.image(for: function.type)

            let name: String
            if let cname = catalog.name(for: function.type) {
                name = cname
            } else {
                name = "f\(index)"
            }
            attributes.append(FunctionAttributes(function: function, name: name, icon: icon))
        }
        return attributes
    }
        
    var body: some View {
            HStack {
                ForEach(functionAttributes, id: \.function.nr) { fattrs in
                    Button {
                        toggleFunction(function: fattrs.function)
                    } label: {
                        if let image = fattrs.icon {
                            Image(nsImage: image)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                        } else {
                            Text("f\(fattrs.function.nr)")
                        }
                    }
                    .if(functionState(function: fattrs.function), transform: { $0.foregroundColor(.yellow) })
                    .help("f\(fattrs.function.nr): \(fattrs.name)")
                    .buttonStyle(.borderless)
                    .fixedSize()
                }
            }
    }
    
    func functionState(function: CommandLocomotiveFunction) -> Bool {
        functions.states[function.nr] == 1
    }
    
    func toggleFunction(function: CommandLocomotiveFunction) {
        let state = functionState(function: function)
        let newState: UInt8 = state ? 0 : 1
        functions.states[function.nr] = newState
        interface.execute(command: .function(address: locomotive.address,
                                             decoderType: locomotive.decoder,
                                             index: function.nr,
                                             value: newState)) {
            // no-op
        }
    }
}

struct TrainFunctionsView_Previews: PreviewProvider {
    
    static let locomotive = {
        var loc = Locomotive()
        for index in 0...20 {
            loc.functions.definitions.append(CommandLocomotiveFunction(nr: UInt8(index), state: 0, type: UInt32(index)+1))
        }
        return loc
    }()
    
    static var previews: some View {
        TrainControlFunctionsView(locomotive: locomotive, interface: MarklinInterface(), catalog: LocomotiveFunctionsCatalog(), functions: locomotive.functions)
    }
}
