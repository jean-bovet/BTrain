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

struct RouteScriptEditingView: View {
    @ObservedObject var layout: Layout

    var body: some View {
        LayoutElementsEditingView(layout: layout, new: {
            layout.newRouteScript()
        }, delete: { script in
            layout.routeScripts.remove(script.id)
        }, duplicate: { script in
            layout.duplicate(script: script)
        }, sort: {
            layout.routeScripts.elements.sort {
                $0.name < $1.name
            }
        }, elementContainer: $layout.routeScripts, row: { script in
            UndoProvider(script) { script in
                TextField("", text: script.name)
            }
        }) { script in
            RouteScriptEditorView(layout: layout, script: script)
        }
    }
}

struct RouteScriptEditingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConfigurationSheet(title: "Routes") {
                RouteScriptEditingView(layout: RouteScriptEditorView_Previews.layout)
            }
        }
        Group {
            ConfigurationSheet(title: "Routes") {
                RouteScriptEditingView(layout: Layout())
            }
        }.previewDisplayName("Empty")
    }
}
