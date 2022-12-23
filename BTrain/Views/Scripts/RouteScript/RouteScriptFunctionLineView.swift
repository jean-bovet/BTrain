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

struct RouteScriptFunctionLineView: View {
    let doc: LayoutDocument
    let catalog: LocomotiveFunctionsCatalog
    @Binding var function: RouteItemFunction
    
    var loc: Locomotive? {
        doc.layout.locomotives[function.locomotive]
    }
    
    var body: some View {
        HStack {
            LocPicker(doc: doc, emptyLabel: "Any Locomotive", selectedLoc: $function.locomotive)
                .labelsHidden()
                .fixedSize()

            Picker("State:", selection: $function.trigger) {
                Text("Enable").tag(RouteItemFunction.Trigger.enable)
                Text("Disable").tag(RouteItemFunction.Trigger.disable)
                Text("Pulse").tag(RouteItemFunction.Trigger.pulse)
            }
            .labelsHidden()
            .fixedSize()

            if let loc = loc {
                Picker("Function:", selection: $function.index) {
                    ForEach(loc.functions.definitions, id: \.self) { def in
                        HStack {
                            if let name = catalog.name(for: def.type) {
                                Text("f\(def.nr): \(name) (\(def.type))")
                            } else {
                                Text("f\(def.nr): \(def.type)")
                            }
                            if let image = catalog.image(for: def.type, state: true) {
                                Image(nsImage: image)
                                    .renderingMode(.template)
                            }
                        }.tag(def.nr as UInt8?)
                    }
                }
                .labelsHidden()
                .fixedSize()
            } else {
                Picker("Function:", selection: $function.type) {
                    ForEach(catalog.globalTypes, id: \.self) { type in
                        HStack {
                            if let name = catalog.name(for: type) {
                                Text("\(name) (\(type))")
                            } else {
                                Text("Type \(type)")
                            }
                            if let image = catalog.image(for: type, state: true) {
                                Image(nsImage: image)
                                    .renderingMode(.template)
                            }
                        }.tag(type)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            switch function.trigger {
            case .enable, .disable:
                Stepper("after \(String(format: "%.1f", function.duration)) s.",
                        value: $function.duration,
                        in: 0 ... 10, step: 0.5)
                    .fixedSize()
            case .pulse:
                Stepper("for \(String(format: "%.1f", function.duration)) s.",
                        value: $function.duration,
                        in: 0 ... 10, step: 0.5)
                    .fixedSize()
            }
        }
    }
}

struct RouteScriptFunctionLineView_Previews: PreviewProvider {
    static let doc = LayoutDocument(layout: Layout())
    
    static let catalog = {
        let catalog = LocomotiveFunctionsCatalog(interface: MarklinInterface())
        catalog.add(attributes: .preview(type: 1, name: "Light"))
        catalog.add(attributes: .preview(type: 2, name: "Cabin Light"))
        catalog.add(attributes: .preview(type: 3, name: "Horn"))
        return catalog
    }()

    static var previews: some View {
        VStack(alignment: .leading) {
            RouteScriptFunctionLineView(doc: doc, catalog: catalog, function: .constant(RouteItemFunction(type: 1, trigger: .enable)))
            RouteScriptFunctionLineView(doc: doc, catalog: catalog, function: .constant(RouteItemFunction(type: 2, trigger: .disable)))
            RouteScriptFunctionLineView(doc: doc, catalog: catalog, function: .constant(RouteItemFunction(type: 3, trigger: .pulse)))
        }
    }
}

extension CommandLocomotiveFunctionAttributes {
    static func preview(type: UInt32, name: String) -> CommandLocomotiveFunctionAttributes {
        .init(type: type, name: name, activeSvgIcon: nil, inactiveSvgIcon: nil)
    }
}
