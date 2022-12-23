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

    let functionsController: TrainFunctionsController

    @ObservedObject var functions: LocomotiveFunctions

    struct FunctionAttributes {
        let function: CommandLocomotiveFunction
        let name: String
        let icon: NSImage?
    }

    var functionAttributes: [FunctionAttributes] {
        var attributes = [FunctionAttributes]()
        for (index, definition) in functions.definitions.enumerated() {
            let icon = catalog.image(for: definition.type, state: functionState(function: definition))

            let name: String
            if let cname = catalog.name(for: definition.type) {
                name = cname
            } else {
                name = "f\(index)"
            }
            attributes.append(FunctionAttributes(function: definition, name: name, icon: icon))
        }
        return attributes
    }

    static let iconSize = 20.0

    let columns = [
        GridItem(.adaptive(minimum: iconSize)),
    ]

    var body: some View {
        LazyVGrid(columns: columns) {
            ForEach(functionAttributes, id: \.function.nr) { fattrs in
                Button {
                    toggleFunction(function: fattrs.function)
                } label: {
                    if let image = fattrs.icon {
                        Image(nsImage: image)
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: TrainControlFunctionsView.iconSize, height: TrainControlFunctionsView.iconSize)
                    } else {
                        Text("f\(fattrs.function.nr)")
                    }
                }
                .if(functionState(function: fattrs.function), transform: { $0.foregroundColor(.yellow) })
                .help("f\(fattrs.function.nr): \(fattrs.name) (\(fattrs.function.type))")
                .buttonStyle(.borderless)
                .fixedSize()
            }
        }
    }

    private func functionState(function: CommandLocomotiveFunction) -> Bool {
        functions.states[function.nr] == 1
    }

    private func toggleFunction(function: CommandLocomotiveFunction) {
        let state = functionState(function: function)
        // Note: the state of the function will be updated
        // when the acknowledgement from the Digital Controller comes back
        functionsController.execute(locomotive: locomotive,
                                    function: function,
                                    trigger: state ? .disable : .enable,
                                    duration: 0)
    }
}

struct TrainFunctionsView_Previews: PreviewProvider {
    static let locomotive = {
        var loc = Locomotive()
        for index in 0 ... 20 {
            loc.functions.definitions.append(CommandLocomotiveFunction(nr: UInt8(index), state: 0, type: UInt32(index) + 1))
        }
        return loc
    }()

    static var previews: some View {
        TrainControlFunctionsView(locomotive: locomotive,
                                  interface: MarklinInterface(),
                                  catalog: LocomotiveFunctionsCatalog(interface: MarklinInterface()),
                                  functionsController: TrainFunctionsController(catalog: nil, interface: MarklinInterface()),
                                  functions: locomotive.functions)
            .frame(width: 200)
    }
}
