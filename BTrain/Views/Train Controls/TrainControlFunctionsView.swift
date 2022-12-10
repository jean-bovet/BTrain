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
    
    struct FunctionAttributes {
        let index: Int
        let name: String
        let icon: NSImage?
    }

    var functionAttributes: [FunctionAttributes] {
        var attributes = [FunctionAttributes]()
        for (index, function) in locomotive.functions.enumerated() {
            let cmdFunc = CommandLocomotiveFunction(identifier: function.identifier)
            let info = interface.attributes(about: cmdFunc)

            let icon: NSImage?
            if let svg = info?.svgIcon, let data = svg.data(using: .utf8) {
                icon = NSImage(data: data)
            } else {
                icon = nil
            }
            
            let name: String
            if let info = info {
                name = info.name
            } else {
                name = "f\(index)"
            }
            attributes.append(FunctionAttributes(index: index, name: name, icon: icon))
        }
        return attributes
    }
        
    var body: some View {
            HStack {
                ForEach(functionAttributes, id: \.index) { fattrs in
                    Button {
                    
                    } label: {
                        if let image = fattrs.icon {
                            Image(nsImage: image)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                        } else {
                            Text("f\(fattrs.index)")
                        }
                    }
//                    .foregroundColor(.yellow)
                    .help("f\(fattrs.index): \(fattrs.name)")
                    .buttonStyle(.borderless)
                    .fixedSize()
                }
            }
    }
}

struct TrainFunctionsView_Previews: PreviewProvider {
    
    static let locomotive = {
        var loc = Locomotive()
        for index in 0...20 {
            loc.functions.append(CommandLocomotiveFunction(identifier: UInt32(index+1)))
        }
        return loc
    }()
    
    static var previews: some View {
        TrainControlFunctionsView(locomotive: locomotive, interface: MarklinInterface())
    }
}
